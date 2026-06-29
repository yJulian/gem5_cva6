```mermaid
graph TD
    %% Globaler Start für einen Taktzyklus
    Start([Beginn eines neuen Taktzyklus]) --> InitCLK[Clock-Signal auf LOW setzen]
    InitCLK --> Choice{Welche Operation steht an?}

    %% ==================== READ PATH ====================
    Choice -->|Read Request| R_Inputs["1. Eingänge setzen vor eval:<br/>- set_noc_req_ar_ready_i = !ar_busy && !retryPkt<br/>- set_noc_req_r_valid_i = r_data_ready<br/>- Daten/ID/Last an R-Kanal anlegen wenn r_data_ready"]
    R_Inputs --> R_Eval1["2. core->eval aufrufen<br/>Kombinatorische Pfade stabilisieren sich"]
    
    R_Eval1 --> R_CheckAR{3. Nach eval: ar_ready_i == 1 <br/>und get_noc_req_ar_valid_o == 1?}
    
    R_CheckAR -->|Ja: AR-Handshake erfolgt| R_GenPkt["4. Paket erzeugen:<br/>- Packet::createRead(req)<br/>- port.sendTimingReq(pkt)<br/>- ar_busy = true"]
    R_CheckAR -->|Nein| R_CheckR{5. Nach eval: r_data_ready == 1 <br/>und get_noc_req_r_ready_o == 1?}
    
    R_GenPkt --> R_CheckR
    
    R_CheckR -->|Ja: R-Beat-Handshake erfolgt| R_NextBeat{Letztes Beat?<br/>read_beat == read_len}
    R_CheckR -->|Nein| R_Edge[6. Flankenwechsel: Clock auf HIGH setzen]
    
    R_NextBeat -->|Ja| R_Clear[ar_busy = false, r_data_ready = false]
    R_NextBeat -->|Nein| R_Inc[read_beat++]
    
    R_Clear --> R_Edge
    R_Inc --> R_Edge

    %% ==================== WRITE PATH ====================
    Choice -->|Write Request| W_Inputs["1. Eingänge setzen vor eval:<br/>- set_noc_req_aw_ready_i = !aw_busy && !retryWritePkt<br/>- set_noc_req_w_ready_i = aw_busy<br/>- set_noc_req_b_valid_i = b_resp_ready"]
    W_Inputs --> W_Eval1["2. core->eval aufrufen<br/>Kombinatorische Pfade stabilisieren sich"]
    
    W_Eval1 --> W_CheckAW{3. Nach eval: aw_ready_i == 1 <br/>und get_noc_req_aw_valid_o == 1?}
    
    W_CheckAW -->|Ja: AW-Handshake erfolgt| W_StoreAddr["4. Adresse & Metadata puffern<br/>- aw_busy = true<br/>- Puffer für W-Daten vorbereiten"]
    W_CheckAW -->|Nein| W_CheckW{5. Nach eval: w_ready_i == 1 <br/>und get_noc_req_w_valid_o == 1?}
    
    W_StoreAddr --> W_CheckW
    
    W_CheckW -->|Ja: W-Beat-Handshake erfolgt| W_StoreData["6. Byte-Daten in Puffer schreiben<br/>get_noc_req_w_data_o"]
    W_CheckW -->|Nein| W_CheckB{8. Nach eval: b_valid_i == 1 <br/>und get_noc_req_b_ready_o == 1?}
    
    W_StoreData --> W_IsLast{Letztes Beat?<br/>get_noc_req_w_last_o == 1}
    W_IsLast -->|Ja| W_GenPkt["7. gem5 Write-Paket bauen:<br/>- Packet::createWrite(req)<br/>- port.sendTimingReq(pkt)<br/>- aw_busy = false"]
    W_IsLast -->|Nein| W_CheckB
    W_GenPkt --> W_CheckB
    
    W_CheckB -->|Ja: B-Handshake erfolgt| W_ClearB[b_resp_ready = false]
    W_CheckB -->|Nein| W_Edge[9. Flankenwechsel: Clock auf HIGH setzen]
    
    W_ClearB --> W_Edge

    %% Ende des Zyklus
    R_Edge --> W_Eval2["10. core->eval aufrufen mit CLK=1<br/>Zustandsregister im RTL-Core schalten um"]
    W_Edge --> W_Eval2
    W_Eval2 --> EndCycle([Zyklus beendet / Nächster Takt])

    style R_Eval1 fill:#f9f,stroke:#333,stroke-width:2px
    style W_Eval1 fill:#f9f,stroke:#333,stroke-width:2px
    style W_Eval2 fill:#f9f,stroke:#333,stroke-width:2px
    style R_GenPkt fill:#bbf,stroke:#333,stroke-width:1px
    style W_GenPkt fill:#bbf,stroke:#333,stroke-width:1px