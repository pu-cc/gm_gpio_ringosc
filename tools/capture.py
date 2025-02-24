import os
import serial
import matplotlib
import matplotlib.pyplot as plt
import numpy as np
import struct
import time
import subprocess
from datetime import datetime

# Use the 'tkagg' backend for non-interactive plotting
matplotlib.use('tkagg')

# UART configuration
PORT = '/dev/ttyUSB1'
BAUDRATE = 115200

git_push_enable = False
if git_push_enable:
    print("Info: push_to_github is enabled!")
else:
    print("Info: push_to_github is NOT enabled!")

GITHUB_USER  = os.getenv("GITHUB_USERNAME")
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")

if not GITHUB_USER or not GITHUB_TOKEN:
    print("Error: GitHub credentials not found. Set GITHUB_USERNAME and GITHUB_TOKEN as environment variables.")
    exit(1)

GIT_REPO_URL = f"https://{os.getenv('GITHUB_USERNAME')}:{GITHUB_TOKEN}@github.com/pu-cc/gm_gpio_ringosc.git"

def read_uart_data(serial_port):
    """Reads 8 bytes from the UART and returns a 32-bit integer."""
    data = serial_port.read(16)
    if len(data) == 16:
        return struct.unpack('>IIII', data)  # Unpack as big-endian 32-bit integer
    else:
        return None, None, None, None

def compensate_temperature(raw_temp24, dig_T1=0x6D42, dig_T2=0x6877, dig_T3=0xFC18):
    raw_temp = raw_temp24 >> 4
    var1 = (((raw_temp >> 3) - (dig_T1 << 1)) * dig_T2) >> 11
    temp_diff = (raw_temp >> 4) - dig_T1
    var2 = (((temp_diff * temp_diff) >> 12) * dig_T3) >> 14
    t_fine = var1 + var2
    temperature = (t_fine * 5 + 128) >> 8  # Temperature in degree C * 100

    return temperature

def get_log_file():
    today = datetime.now().strftime("%Y-%m-%d")
    return f"db/log_{today}.csv"

def push_to_github(file_path):
    try:
        subprocess.run(["git", "add", file_path], check=True)

        today = datetime.now().strftime("%Y-%m-%d")
        commit_message = f"Stress test log file: {today}"
        subprocess.run(["git", "commit", "-m", commit_message], check=True)

        subprocess.run(["git", "remote", "set-url", "origin", GIT_REPO_URL], check=True)
        subprocess.run(["git", "push", "origin", "main"], check=True)

    except subprocess.CalledProcessError as e:
        print(f"Failed to push to github: {e}")
        exit(1)

def main():
    # Open the UART connection
    try:
        ser = serial.Serial(PORT, BAUDRATE, timeout=1)
        ser.dtr = 0 # keep dtr=reset off
        print(f"Connected to {PORT} at {BAUDRATE} baud.")
    except serial.SerialException as e:
        print(f"Failed to connect: {e}")
        return

    # Setup for real-time plotting
    plt.ion()
    fig, (ax1, ax2) = plt.subplots(2, sharex=True, height_ratios=[3,1])
    max_points = 100  # Limit the number of points shown on the plot

    # Create initial empty lines
    line1, = ax1.plot([], [], 'b-', label='3V6 Osc. (MHz)')
    line2, = ax1.plot([], [], 'r-', label='2V5 Osc. (MHz)')
    line3, = ax1.plot([], [], 'y-', label='1V8 Osc. (MHz)')
    ax1.set_title("Real-time UART Data")
    ax1.set_ylabel("Osc. Value (MHz)")
    ax1.legend()
    ax1.grid(True, linestyle=':')

    line4, = ax2.plot([], [], 'g-')
    ax2.set_xlabel("Time (s)")
    ax2.set_ylabel("Temperature (C)")
    ax2.grid(True, linestyle=':')

    x_data, y1_data, y2_data, y3_data, y4_data = [], [], [], [], []

    start_time = time.time()
    running = True

    def on_close(event):
        nonlocal running
        print("Window closed, exiting application...")
        running = False

    fig.canvas.mpl_connect('close_event', on_close)

    last_log_file = ''

    try:
        while running:
            # Open a file for writing
            log_file = get_log_file()
            log_exists = os.path.exists(log_file)

            if not log_exists:
                if last_log_file != '' and git_push_enable:
                    push_to_github(last_log_file)
                else:
                    last_log_file = log_file

            with open(log_file, mode='a', newline='', buffering=1) as file:
                value3v6, value2v5, value1v8, raw_temp24 = read_uart_data(ser)
                if value3v6 is not None and value2v5 is not None and value1v8 is not None and raw_temp24 is not None:
                    ctemp = compensate_temperature(raw_temp24) / 100.0

                    elapsed_time = time.time() - start_time
                    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

                    # Write timestamp and value to file
                    file.write(f"{current_time}; {value3v6}; {value2v5}; {value1v8}; {ctemp}\n")

                    # Update data for plotting
                    x_data.append(elapsed_time)
                    y1_data.append(value3v6 / 1e6)
                    y2_data.append(value2v5 / 1e6)
                    y3_data.append(value1v8 / 1e6)
                    y4_data.append(ctemp)
                    if len(x_data) > max_points:
                        x_data.pop(0)
                        y1_data.pop(0)
                        y2_data.pop(0)
                        y3_data.pop(0)
                        y4_data.pop(0)

                    # Update plot lines
                    line1.set_xdata(x_data)
                    line1.set_ydata(y1_data)
                    line2.set_xdata(x_data)
                    line2.set_ydata(y2_data)
                    line3.set_xdata(x_data)
                    line3.set_ydata(y3_data)
                    line4.set_xdata(x_data)
                    line4.set_ydata(y4_data)

                    # Rescale axes to fit the data
                    ax1.relim()
                    ax1.autoscale_view()
                    ax2.relim()
                    ax2.autoscale_view()

                    plt.pause(0.01)

    except KeyboardInterrupt:
        print("Exiting...")

    except IOError as e:
        print(f"Failed to open file: {e}")

    finally:
        ser.close()
        file.close()
        plt.ioff()
        plt.show()

if __name__ == "__main__":
    main()
