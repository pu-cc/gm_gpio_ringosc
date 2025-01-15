import serial
import matplotlib.pyplot as plt
import numpy as np
import struct
import time
from datetime import datetime

# UART configuration
PORT = '/dev/ttyUSB2'
BAUDRATE = 115200

def read_uart_data(serial_port):
    """Reads 8 bytes from the UART and returns a 32-bit integer."""
    data = serial_port.read(8)  # Read 8 bytes
    if len(data) == 8:
        return struct.unpack('>II', data)  # Unpack as big-endian 32-bit integer
    else:
        return None, None

def main():
    # Open the UART connection
    try:
        ser = serial.Serial(PORT, BAUDRATE, timeout=1)
        print(f"Connected to {PORT} at {BAUDRATE} baud.")
    except serial.SerialException as e:
        print(f"Failed to connect: {e}")
        return

    # Open a file for writing
    file_name = f"db/uart_data{datetime.now().strftime("%Y-%m-%d_%H-%M-%S")}.txt"
    try:
        file = open(file_name, "w", buffering=1)
        print(f"Writing data to {file_name}.")
    except IOError as e:
        print(f"Failed to open file: {e}")
        return

    # Setup for real-time plotting
    plt.ion()
    fig, ax = plt.subplots()
    x_data, y1_data, y2_data = [], [], []
    max_points = 100  # Limit the number of points shown on the plot

    start_time = time.time()

    running = True

    def on_close(event):
        nonlocal running
        print("Window closed, exiting application...")
        running = False

    fig.canvas.mpl_connect('close_event', on_close)

    try:
        while running:
            value3v3, value2v5 = read_uart_data(ser)
            if value3v3 is not None and value2v5 is not None:
                elapsed_time = time.time() - start_time
                current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

                # Write timestamp and value to file
                file.write(f"{current_time}; {value3v3}; {value2v5};\n")

                # Update data for plotting
                x_data.append(elapsed_time)
                y1_data.append(value3v3 / 1e6)
                y2_data.append(value2v5 / 1e6)
                if len(x_data) > max_points:
                    x_data.pop(0)
                    y1_data.pop(0)
                    y2_data.pop(0)

                # Update plot
                ax.clear()
                ax.plot(x_data, y1_data, marker='', linestyle='-', color='b', label='3V3 Osc. (MHz)')
                ax.plot(x_data, y2_data, marker='', linestyle='-', color='r', label='2V5 Osc. (MHz)')
                ax.set_title("Real-time UART Data")
                ax.set_xlabel("Time (s)")
                ax.set_ylabel("Value (MHz)")
                ax.legend()
                ax.grid(True, linestyle=':')
                plt.pause(0.01)  # Small delay to update the plot

    except KeyboardInterrupt:
        print("Exiting...")

    finally:
        ser.close()
        file.close()
        plt.ioff()
        plt.show()

if __name__ == "__main__":
    main()
