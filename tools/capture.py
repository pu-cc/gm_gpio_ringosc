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
    data = serial_port.read(12)
    if len(data) == 12:
        return struct.unpack('>III', data)  # Unpack as big-endian 32-bit integer
    else:
        return None, None, None

def compensate_temperature(raw_temp24, dig_T1=0x6D42, dig_T2=0x6877, dig_T3=0xFC18):
    raw_temp = raw_temp24 >> 4
    var1 = (((raw_temp >> 3) - (dig_T1 << 1)) * dig_T2) >> 11
    temp_diff = (raw_temp >> 4) - dig_T1
    var2 = (((temp_diff * temp_diff) >> 12) * dig_T3) >> 14
    t_fine = var1 + var2
    temperature = (t_fine * 5 + 128) >> 8  # Temperature in degree C * 100

    return temperature

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
    fig, (ax1, ax2) = plt.subplots(2, sharex=True, height_ratios=[3,1])
    max_points = 100  # Limit the number of points shown on the plot

    # Create initial empty lines
    line1, = ax1.plot([], [], 'b-', label='3V6 Osc. (MHz)')
    line2, = ax1.plot([], [], 'r-', label='2V5 Osc. (MHz)')
    ax1.set_title("Real-time UART Data")
    ax1.set_ylabel("Osc. Value (MHz)")
    ax1.legend()
    ax1.grid(True, linestyle=':')

    line3, = ax2.plot([], [], 'g-')
    ax2.set_xlabel("Time (s)")
    ax2.set_ylabel("Temperature (C)")
    ax2.grid(True, linestyle=':')

    x_data, y1_data, y2_data, y3_data = [], [], [], []

    start_time = time.time()
    running = True

    def on_close(event):
        nonlocal running
        print("Window closed, exiting application...")
        running = False

    fig.canvas.mpl_connect('close_event', on_close)

    try:
        while running:
            value3v6, value2v5, raw_temp24 = read_uart_data(ser)
            if value3v6 is not None and value2v5 is not None and raw_temp24 is not None:
                ctemp = compensate_temperature(raw_temp24) / 100.0

                elapsed_time = time.time() - start_time
                current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

                # Write timestamp and value to file
                file.write(f"{current_time}; {value3v6}; {value2v5}; {ctemp}\n")

                # Update data for plotting
                x_data.append(elapsed_time)
                y1_data.append(value3v6 / 1e6)
                y2_data.append(value2v5 / 1e6)
                y3_data.append(ctemp)
                if len(x_data) > max_points:
                    x_data.pop(0)
                    y1_data.pop(0)
                    y2_data.pop(0)
                    y3_data.pop(0)

                # Update plot lines
                line1.set_xdata(x_data)
                line1.set_ydata(y1_data)
                line2.set_xdata(x_data)
                line2.set_ydata(y2_data)
                line3.set_xdata(x_data)
                line3.set_ydata(y3_data)

                # Rescale axes to fit the data
                ax1.relim()
                ax1.autoscale_view()
                ax2.relim()
                ax2.autoscale_view()

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
