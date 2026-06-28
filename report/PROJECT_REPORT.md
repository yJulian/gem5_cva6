# gem5 & CVA6 RTL Co-Simulation: Projekt-Report zur RTL-Schnittstelle

Dieser Bericht beschreibt die Architektur, Funktionsweise und Integration der **gem5 & CVA6 RTL Co-Simulation**-Schnittstelle. Das System integriert die RTL-Beschreibung des OpenHW Group CVA6 (Ariane) RISC-V-Prozessors sowie einen benutzerdefinierten SystemVerilog FIFO-DMA-Beschleuniger in den gem5-Simulator.

> [!IMPORTANT]
> **Klarstellung zu Tests und Konfigurationen:**
> Alle im Projekt vorhandenen Python-Konfigurationsskripte (im Verzeichnis `configs/`) sowie die bare-metal Assembler-Programme (im Verzeichnis `scratch/`) sind reine **Test- und Verifikationstools**. Sie haben an sich keine architektonische Relevanz für die eigentliche Funktionalität der RTL-Schnittstelle, sondern dienen ausschließlich deren Validierung.

---

## 1. Systemarchitektur & Schnittstellen-Übersicht

Das Co-Simulations-Framework basiert auf einer klaren Dreischichten-Architektur. Die RTL-Modelle der Hardwarekomponenten werden mittels Verilator in C++-Klassen übersetzt und als dynamisch ladbare Bibliotheken (`.so`) bereitgestellt. Dadurch bleibt der gem5-Simulator prozesstechnisch von den konkreten RTL-Details getrennt.

### Strukturdiagramm der Co-Simulation

```mermaid
graph TD
    subgraph Test_Layer ["Konfiguration & Test-Ebene (Keine funktionale Relevanz)"]
        Config["Python Test-Konfiguration (z. B. run_accel_l2.py)"]
    end

    subgraph gem5 ["gem5 Simulator (C++ Hauptprozess)"]
        subgraph CPU_Wrapper ["CVA6RtlCPU SimObject (Wrapper)"]
            AXI_Bufs[AXI Channel Buffers]
            TickLoop[Taktzyklus Event Loop (tick)]
            InstPort["inst_port (RequestPort)"]
            DataPort["data_port (RequestPort)"]
        end

        subgraph Interconnect ["Speicherhierarchie"]
            L2Bus[L2XBar Bus]
            L2[L2 Cache 256KiB]
            MemBus[SystemXBar Bus]
            RAM[SimpleMemory 256MB]
        end

        subgraph Accel_Wrapper ["FifoAccelerator SimObject"]
            PioPort["pio (MMIO Slave Port)"]
            DmaPort["dma (DMA Master Port)"]
        end
    end

    subgraph RTL_Libraries ["Dynamische RTL-Bibliotheken (Verilated .so)"]
        subgraph CVA6_RTL ["libVcva6_top.so"]
            Core[CVA6 RTL Core]
        end
        subgraph Accel_RTL ["libfifo_accel.so"]
            FifoSV[fifo_accel RTL]
        end
    end

    %% Verbindungen
    InstPort -->|Instruction Reads| L2Bus
    DataPort -->|Data Read/Write| L2Bus
    L2Bus --> L2
    L2 --> MemBus
    MemBus --> RAM
    
    %% Beschleuniger
    MemBus -->|PIO MMIO Registers| PioPort
    DmaPort -->|DMA Read/Write| MemBus

    %% Dynamic Linking Boundaries
    CPU_Wrapper <-->|CVA6RtlCoreInterface| Core
    Accel_Wrapper <-->|FifoAccelInterface| FifoSV

    %% Styling
    classDef test fill:#ffd343,stroke:#3b7ab0,stroke-width:2px,color:#000;
    classDef gem5cpp fill:#e0f2fe,stroke:#0284c7,stroke-width:2px,color:#000;
    classDef rtl fill:#f0fdf4,stroke:#16a34a,stroke-width:2px,color:#000;
    class Config test;
    class CPU_Wrapper,Interconnect,L2Bus,L2,MemBus,RAM,Accel_Wrapper gem5cpp;
    class CVA6_RTL,Accel_RTL,Core,FifoSV rtl;
```

---

## 2. Dynamic Loading (DSO-Konzept)

Um eine enge Kopplung und somit ständige Neukompilierung des gesamten gem5-Simulators bei Änderungen an der RTL zu vermeiden, lädt gem5 die RTL-Kerne dynamisch zur Laufzeit:

*   **Verilator-Kompilierung:** Das RTL-Design wird über Verilator in C++-Code übersetzt und als Shared Library (`libVcva6_top.so` bzw. `libfifo_accel.so`) kompiliert.
*   **Abstraktion:** Die Schnittstellen definieren rein virtuelle C++-Basisklassen:
    *   [CVA6RtlCoreInterface](file:///home/julian/gem5_cva6/gem5/src/cpu/cva6/cva6_rtl_core_interface.hh) für den Prozessor.
    *   [FifoAccelInterface](file:///home/julian/gem5_cva6/gem5/src/cpu/cva6/fifo_accel_interface.hh) für den FIFO-Beschleuniger.
*   **Laufzeit-Bindung (`dlopen`):** Im Konstruktor des gem5 CPU-SimObjects [CVA6RtlCPU](file:///home/julian/gem5_cva6/gem5/src/cpu/cva6/cva6_rtl_cpu.cc#L19-L85) wird die Bibliothek geladen. Mittels `dlsym` werden die Factory-Methoden `create_core()` und `destroy_core()` aufgelöst, um Instanzen des verilateten Modells zu erzeugen.

---

## 3. Funktionsweise der CVA6-RTL-CPU-Schnittstelle

Das SimObject [CVA6RtlCPU](file:///home/julian/gem5_cva6/gem5/src/cpu/cva6/cva6_rtl_cpu.cc) bildet die Brücke zwischen dem transaktionsbasierten Speichersystem von gem5 (`gem5::Packet`) und der pinbasierten AXI4-Schnittstelle des verilateten CVA6-Kerns.

### 3.1 Taktzyklus-Orchestrierung (Tick Loop)

Das Weiterschalten des RTL-Prozessors erfolgt synchron zu gem5 über ein registriertes `tickEvent`. Jede Simulationsrunde führt in der [tick()](file:///home/julian/gem5_cva6/gem5/src/cpu/cva6/cva6_rtl_cpu.cc#L227-L521)-Methode folgende Sequenz aus:

```
[Simulationszyklus startet]
       │
       ▼
1. Reset-Logik überprüfen ──────► rst_ni auf 0 setzen (für die ersten 10 Zyklen) bzw. auf 1 setzen.
       │
       ▼
2. fallende Flanke (clk_i=0) ────► Inputs (AR/AW/W/R/B Kanäle) auf die Pins legen.
       │                          core->eval() aufrufen zur kombinatorischen Fortpflanzung.
       ▼
3. Handshake-Verarbeitung ──────► Prüfen, ob vor dem nächsten Takt AXI-Handshakes stattfinden
       │                          (z. B. AR-Valid & AR-Ready). Falls ja, gem5-Pakete generieren
       │                          und asynchron via inst_port/data_port (sendTimingReq) senden.
       ▼
4. steigende Flanke (clk_i=1) ────► clk_i auf 1 setzen.
       │                          core->eval() aufrufen, um Zustandsänderungen im RTL-Kern zu triggern.
       ▼
5. Commits/Interrupts prüfen ───► Abfragen von illegalen Instruktionen oder 'ebreak'-Signalen,
       │                          um die Simulation ggf. definiert zu beenden.
       ▼
6. Re-Schedule ─────────────────► Nächstes tickEvent für den nächsten Zyklus einplanen.
```

### 3.2 AXI-Protokoll zu gem5 Packet Mapping

Da gem5 mit High-Level `PacketPtr`-Objekten arbeitet und die RTL mit dedizierten Bus-Signalen kommuniziert, übersetzt der C++-Wrapper die AXI-Phasen wie folgt:

#### Leseoperationen (AR- & R-Kanal)
1. **AR-Handshake:** Wenn der RTL-Kern das Signal `noc_req_ar_valid_o` ausgibt, prüft der Wrapper, ob er bereit ist. Falls ja, erzeugt er ein Lese-Paket (`Packet::createRead`) mit der Zieladresse, Größe und Burstlänge.
2. **gem5-Sendephase:** Das Paket wird über den entsprechenden Port (`inst_port` bei Instruction-Fetch, ansonsten `data_port`) abgeschickt.
3. **Pufferung:** Sobald das Speichersubsystem über `handleTimingResp()` antwortet, werden die Daten im CPU-Wrapper zwischengespeichert und `r_data_ready` auf true gesetzt.
4. **R-Handshake:** Bei der nächsten fallenden Flanke legt der Wrapper die Daten auf `noc_resp_r_data_i` und setzt `noc_resp_r_valid_i` auf 1. Sobald der Kern `noc_req_r_ready_o` signalisiert, ist der Lese-Beat abgeschlossen.

#### Schreiboperationen (AW-, W- & B-Kanal)
1. **AW-Handshake:** Erkennt der Wrapper ein valides `noc_req_aw_valid_o`, speichert er Zieladresse, Transaktions-ID und Burst-Informationen ab.
2. **W-Handshake (Datenbeats):** Für jeden Datenbeat (`noc_req_w_valid_o`) wird ein Schreib-Paket (`Packet::createWrite`) erzeugt und über `data_port.sendTimingReq()` an gem5 übergeben.
3. **B-Handshake:** Nachdem alle Beats geschrieben wurden und gem5 alle Schreibzugriffe per `handleTimingResp()` bestätigt hat, setzt der Wrapper `noc_resp_b_valid_i` auf 1, um dem Prozessor den Erfolg der Transaktion zu signalisieren.

---

## 4. FIFO-Accelerator RTL-Schnittstelle

Der FIFO-Accelerator ([FifoAccelerator](file:///home/julian/gem5_cva6/gem5/src/cpu/cva6/fifo_accel.cc)) integriert ein separates SystemVerilog-Modul, das zwei Rollen einnimmt:

1. **AXI4-Lite Slave Schnittstelle (MMIO-Register):**
   * Der Prozessor steuert den Beschleuniger über Memory-Mapped I/O (MMIO-Bereich `0x10000` - `0x100FF`).
   * Bei Lese- oder Schreibzugriffen auf diesen Adressbereich fängt das gem5 SimObject die Zugriffe ab, setzt die entsprechenden `s_axi_*` Signale und taktet das RTL-Modul über `stepClock()` so lange durch, bis der Slave-Handshake erfolgt. Dadurch wird der CPU-Lauf blockiert, bis das Register geschrieben/gelesen ist.
2. **AXI4 Master Schnittstelle (DMA Engine):**
   * Nach dem Schreiben von `start_dma` in das **CTRL**-Register liest der Beschleuniger selbstständig Daten von der Quelladresse (`SRC_ADDR`) und schreibt sie an die Zieladresse (`DST_ADDR`).
   * Der Wrapper übersetzt die Master-AXI-Anfragen des Beschleunigers in funktionale Speicherzugriffe (`dmaPort.sendFunctional`), wodurch Daten direkt im gem5-Systemspeicher kopiert werden.

### Register-Map des Beschleunigers

| Register Name | Offset | Typ | Beschreibung |
|---|---|---|---|
| **CTRL** | `0x00` | R/W | Bit 0: `start_dma` (Triggert DMA bei 1)<br>Bit 1: `busy_dma` (Laufende DMA, Read-only)<br>Bit 2: `done_dma` (DMA abgeschlossen, zum Löschen 1 schreiben) |
| **SRC_ADDR** | `0x08` | R/W | 64-Bit Quelladresse im Hauptspeicher (RAM) |
| **DST_ADDR** | `0x10` | R/W | 64-Bit Zieladresse im Hauptspeicher (RAM) |
| **LEN** | `0x18` | R/W | 64-Bit Übertragungslänge (in 64-Bit Wörtern) |
| **STATUS/COUNT** | `0x20` | R | Status des internen Ringpuffers (FIFO leer/voll, Füllstand) |
| **FIFO_DATA** | `0x28` | R/W | Manueller FIFO-Zugriff (Pushen/Poppen von 64-Bit Wörtern) |

---

## 5. Testkomponenten (Ohne funktionale Systemrelevanz)

Die folgenden Komponenten sind ausschließlich Hilfsmittel zur Verifikation und Testung der RTL-Schnittstelle:

*   **Python-Konfigurationen (`configs/cva6/`):**
    *   [run_rtl.py](file:///home/julian/gem5_cva6/configs/cva6/run_rtl.py): Initialisiert die gem5-Simulation, lädt das ELF-Testprogramm und simuliert den CVA6-Prozessor. Die Schleife überwacht periodisch die Adresse `0x80001000` (`tohost`), um den Exit-Status des Programms abzufragen.
    *   [run_accel_l2.py](file:///home/julian/gem5_cva6/configs/cva6/run_accel_l2.py): Entspricht dem RTL-Lauf, bindet jedoch zusätzlich den L2-Cache und den FIFO-Beschleuniger ein.
*   **Bare-Metal Programme (`scratch/`):**
    *   [sum.S](file:///home/julian/gem5_cva6/scratch/sum.S): Ein einfacher Loop-Test, der Zahlen von 1 bis 1000 addiert und bei Erfolg `1` (bzw. bei Fehlschlag `3`) in das `tohost`-Register schreibt.
    *   [test_accel.S](file:///home/julian/gem5_cva6/scratch/test_accel.S): Initialisiert die Register des FIFO-Beschleunigers über MMIO, startet die DMA, pollt das `CTRL`-Register bis zum Abschluss und prüft die Richtigkeit der kopierten Daten.
*   **Abbruch-Signale:**
    *   **`tohost` Schreibzugriff:** Wenn das Testprogramm einen Wert ungleich Null an die Adresse `0x80001000` schreibt, bricht das Python-Testskript ab und wertet den Wert als Exitcode.
    *   **`ebreak`-Instruktion:** Führt das Testprogramm ein `ebreak` aus, wird dies vom wrapper-internen `get_ebreak_o()` erkannt, was zum direkten Beenden der gem5-Simulation führt (`exitSimLoop`).
