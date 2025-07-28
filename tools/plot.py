import os
import sys
import glob
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import pandas as pd

import numpy as np
from sklearn.linear_model import LinearRegression

filter_out_osc_halt = True

def load_csv(csv_path):
    if os.path.isfile(csv_path):
        data = pd.read_csv(csv_path, delimiter=';', header=None,
                           names=['Timestamp', 'GPIO 3V6 DUT Oscillator (MHz)', 'GPIO 2V5 REF Oscillator (MHz)', 'GPIO 1V8 REF Oscillator (MHz)', 'Temperature (C)'],
                           parse_dates=['Timestamp'])
    elif os.path.isdir(csv_path):
        csv_files = glob.glob(os.path.join(csv_path, "*.csv"))
        data_list = [pd.read_csv(file, delimiter=';', header=None, names=['Timestamp', 'GPIO 3V6 DUT Oscillator (MHz)', 'GPIO 2V5 REF Oscillator (MHz)', 'GPIO 1V8 REF Oscillator (MHz)', 'Temperature (C)'], parse_dates=['Timestamp']) for file in csv_files]
        data = pd.concat(data_list, ignore_index=True)
    else:
        print("Invalid path! Please provide a valid CSV file or directory.")
        return

    # Sort by Timestamp (important for correct plotting)
    data = data.sort_values(by='Timestamp')

    # Strip whitespace from column names
    data.columns = data.columns.str.strip()
    if filter_out_osc_halt:
        dut_avg = data['GPIO 3V6 DUT Oscillator (MHz)'].max()
        ref0_avg = data['GPIO 2V5 REF Oscillator (MHz)'].max()
        ref1_avg = data['GPIO 1V8 REF Oscillator (MHz)'].max()
        data = data[data['GPIO 3V6 DUT Oscillator (MHz)'] > dut_avg*0.95]
        data = data[data['GPIO 2V5 REF Oscillator (MHz)'] > ref0_avg*0.95]
        data = data[data['GPIO 1V8 REF Oscillator (MHz)'] > ref1_avg*0.95]
    data['GPIO 3V6 DUT Oscillator (MHz)'] = data['GPIO 3V6 DUT Oscillator (MHz)'] / 1e6
    data['GPIO 2V5 REF Oscillator (MHz)'] = data['GPIO 2V5 REF Oscillator (MHz)'] / 1e6
    data['GPIO 1V8 REF Oscillator (MHz)'] = data['GPIO 1V8 REF Oscillator (MHz)'] / 1e6
    return data

def plot_simple(csv_path):
    data = load_csv(csv_path)

    T = data['Temperature (C)']
    f = data['GPIO 3V6 DUT Oscillator (MHz)']

    # Referenztemperatur (z. B. 25 °C)
    T0 = 25
    T_centered = T - T0

    # Feature-Matrix für Regressionsmodell (z. B. quadratisches Modell)
    X = np.vstack([T_centered, T_centered**2]).T

    # Lineare Regression fitten
    model = LinearRegression().fit(X, f)

    # Temperaturbedingte Frequenzkomponente vorhersagen
    f_temp_model = model.predict(X)

    # Frequenz bereinigt von Temperatur
    f_clean = f - f_temp_model + model.intercept_  # Normiert auf f(T0)

    fig, (ax0, ax1, ax2, ax3) = plt.subplots(4, sharex=True, height_ratios=[1,1,1,1], figsize=(8, 12))

    ax0.plot(data['Timestamp'], data['GPIO 3V6 DUT Oscillator (MHz)'], label='GPIO 3V6 DUT Oscillator (MHz)', color='b', linestyle='-', marker='')
    ax1.plot(data['Timestamp'], data['GPIO 2V5 REF Oscillator (MHz)'], label='GPIO 2V5 REF Oscillator (MHz)', color='r', linestyle='-', marker='')
    ax2.plot(data['Timestamp'], data['GPIO 1V8 REF Oscillator (MHz)'], label='GPIO 1V8 REF Oscillator (MHz)', color='y', linestyle='-', marker='')
    #ax3.plot(data['Timestamp'], data['Temperature (C)'], label='Temperature (C)', color='g', linestyle='-', linewidth=0.5, marker='')
    ax3.plot(data['Timestamp'], f_clean, label='f_clean', color='g', linestyle='-', linewidth=0.5, marker='')
    ax3.plot(data['Timestamp'], f_temp_model, label='f_temp_model', color='r', linestyle='-', linewidth=0.5, marker='')

    ax0.grid()
    ax1.grid()
    ax2.grid()
    ax3.grid()

    ax0.legend(loc="upper right")
    ax1.legend(loc="upper right")
    ax2.legend(loc="upper right")
    ax3.legend(loc="upper right")

    # Formatting the plot
    ax0.xaxis.set_major_formatter(mdates.DateFormatter('%Y-%m-%d %H:%M:%S'))
    plt.xlabel('Timestamp')
    plt.tight_layout()

    # Show the plot
    plt.show()

def plot_drift(csv_path):
    data = load_csv(csv_path)

    # Plot the data
    fig, (ax1, axd0, axd1) = plt.subplots(3, sharex=True, height_ratios=[3,1,1])

    line1, = ax1.plot(data['Timestamp'], data['GPIO 3V6 DUT Oscillator (MHz)'], label='GPIO 3V6 DUT Oscillator (MHz)', color='b', linestyle='-', marker='')
    line2, = ax1.plot(data['Timestamp'], data['GPIO 2V5 REF Oscillator (MHz)'], label='GPIO 2V5 REF Oscillator (MHz)', color='r', linestyle='-', marker='')
    line3, = ax1.plot(data['Timestamp'], data['GPIO 1V8 REF Oscillator (MHz)'], label='GPIO 1V8 REF Oscillator (MHz)', color='y', linestyle='-', marker='')
    ax1.axhline(y=data['GPIO 3V6 DUT Oscillator (MHz)'].min(), color='b', linestyle='--', marker='', linewidth=1)
    ax1.axhline(y=data['GPIO 3V6 DUT Oscillator (MHz)'].max(), color='b', linestyle='--', marker='', linewidth=1)
    ax1.axhline(y=data['GPIO 2V5 REF Oscillator (MHz)'].min(), color='r', linestyle='--', marker='', linewidth=1)
    ax1.axhline(y=data['GPIO 2V5 REF Oscillator (MHz)'].max(), color='r', linestyle='--', marker='', linewidth=1)
    ax1.axhline(y=data['GPIO 1V8 REF Oscillator (MHz)'].min(), color='y', linestyle='--', marker='', linewidth=1)
    ax1.axhline(y=data['GPIO 1V8 REF Oscillator (MHz)'].max(), color='y', linestyle='--', marker='', linewidth=1)
    ax1.set_ylabel('Frequency (MHz)')
    ax1.grid(True)

    ax2 = ax1.twinx()
    line4, = ax2.plot(data['Timestamp'], data['Temperature (C)'], label='Temperature (C)', color='g', linestyle='-', linewidth=0.5, marker='')
    ax2.set_ylabel('Temperature (C)')
    ax2.set_ylim([20, 40])
    ax2.yaxis.label.set_color('g')
    ax2.grid(False)

    difference = (data['GPIO 3V6 DUT Oscillator (MHz)'] - data['GPIO 1V8 REF Oscillator (MHz)']) #/ (3.6 - 1.8)
    line_diff, = axd0.plot(data['Timestamp'], difference,
                      label='Difference: 3V6 DUT - 1V8 REF (MHz)',
                      color='c',
                      linestyle='-', marker='')
    axd0.set_ylabel('Frequency Drift\nNormalized (MHz)')
    axd0.grid(True)
    axd0.legend(loc="upper left")

    difference = (data['GPIO 2V5 REF Oscillator (MHz)'] - data['GPIO 1V8 REF Oscillator (MHz)']) #/ (2.5 - 1.8)
    line_diff, = axd1.plot(data['Timestamp'], difference,
                      label='Difference: 2V5 REF - 1V8 REF (MHz)',
                      color='c',
                      linestyle='-', marker='')
    axd1.set_ylabel('Frequency Drift\nNormalized (MHz)')
    axd1.grid(True)
    axd1.legend(loc="upper left")

    # Merge legends
    lines = [line1, line2, line3, line4]
    labels = [line.get_label() for line in lines]
    ax1.legend(lines, labels, loc="upper left")

    # Formatting the plot
    ax1.xaxis.set_major_formatter(mdates.DateFormatter('%Y-%m-%d %H:%M:%S'))
    plt.xlabel('Timestamp')
    plt.tight_layout()
    #plt.xticks(rotation=45)

    # Show the plot
    mng = plt.get_current_fig_manager()
    mng.window.showMaximized()
    plt.show()

plot_simple(sys.argv[1])
#plot_drift(sys.argv[1])
