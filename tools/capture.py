import serial
import matplotlib
import matplotlib.pyplot as plt
import numpy as np
import struct
import time
from datetime import datetime

# Use the 'tkagg' backend for non-interactive plotting
matplotlib.use('tkagg')

# UART configuration
PORT = '/dev/ttyUSB1'
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
        ser.dtr = 0 # keep dtr=reset off
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
    max_points = 100  # Limit the number of points shown on the plot

    # Create initial empty lines
    line1, = ax.plot([], [], 'b-', label='3V6 Osc. (MHz)')
    line2, = ax.plot([], [], 'r-', label='2V5 Osc. (MHz)')
    ax.set_title("Real-time UART Data")
    ax.set_xlabel("Time (s)")
    ax.set_ylabel("Osc. Value (MHz)")
    ax.legend()
    ax.grid(True, linestyle=':')

    x_data, y1_data, y2_data = [], [], []

    start_time = time.time()
    running = True

    def on_close(event):
        nonlocal running
        print("Window closed, exiting application...")
        running = False

    fig.canvas.mpl_connect('close_event', on_close)

    try:
        while running:
            value3v6, value2v5 = read_uart_data(ser)
            if value3v6 is not None and value2v5 is not None:
                elapsed_time = time.time() - start_time
                current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

                # Write timestamp and value to file
                file.write(f"{current_time}; {value3v6}; {value2v5}\n")

                # Update data for plotting
                x_data.append(elapsed_time)
                y1_data.append(value3v6 / 1e6)
                y2_data.append(value2v5 / 1e6)
                if len(x_data) > max_points:
                    x_data.pop(0)
                    y1_data.pop(0)
                    y2_data.pop(0)

                # Update plot lines
                line1.set_xdata(x_data)
                line1.set_ydata(y1_data)
                line2.set_xdata(x_data)
                line2.set_ydata(y2_data)

                # Rescale axes to fit the data
                ax.relim()
                ax.autoscale_view()

                plt.pause(0.01)

    except KeyboardInterrupt:
        print("Exiting...")

    finally:
        ser.close()
        file.close()
        plt.ioff()
        plt.show()

if __name__ == "__main__":
    main()
