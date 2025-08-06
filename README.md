# serial_receiver_fsm

## Description

In many (older) serial communication protocols, a start and stop bit are delivered with each data byte to help the receiver separate bytes from the stream of bits. A typical setup includes one start bit (0), eight data bits, and one stop bit (1). While there is no transmission (idle), the line is set to logic 1. 

Given a stream of bits, the finite state machine will determine whether the bytes were received correctly. After receiving the start bit and waiting for all eight data bits, it will verify that the stop bit was received correctly. If the expected stop bit does not appear, the FSM waits until it finds one before attempting to receive the next byte.

The FSM will also include a datapath used to output the successfully received data byte. When 'done' is asserted, the 'out_byte' variable must be valid; otherwise, we do not care about the value.

I then changed the serial receiver to enable parity checking. Each data byte is followed by an extra bit for parity checking. Because this design uses odd parity, the nine bits received must contain an odd number of ones.

Only when a byte is correctly received and its parity check succeeds is the done signal asserted. After finding the start bit and waiting for all nine (data and parity) bits, the updated FSM must ensure that the stop bit is correct. If the expected stop bit does not appear, the FSM must wait until it finds one before attempting to receive the next byte.

Of the 8 data bits, the serial protocol sends the least significant bit first.

## File Structure

- `src/`: Source design files
- `tb/`: Testbench files
- `pre-rtl media/`: State diagrams, Circuit schematics, etc
- `post-sim media/`: Timing waveforms, Simulation output, etc

## Tools Used

- Siemens Questa
- EDA Playground

## Features

- Synchronous active-high reset
- One Hot-Encoded States
- Interface for encapsulating signals
- Object-Oriented Programming, randomizing constraints, and assertions for testbench
- Generator, Monitor, Driver, and Scoreboard for modular and reusable verification

## Takeaways

- One-Hot Encoding provides simpler next-state logic and increases the number of flip-flops. This reduces the critical path and improves the speed.
- Learned how to create a testbench using classes, mailboxes, events, and interfaces. Designed a scalable testbench with a logfile that provides for better debugging.
- The Constraint Random Verification allows for higher coverage.
- The Use of assertions helps note the number of errors in the simulation (based on the simulator).

## Project Idea Source

HDLBits
