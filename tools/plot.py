import sys
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import pandas as pd

filter_out_osc_halt = True

def load_and_plot(file_path, remove_pauses=True):
    data = pd.read_csv(file_path, delimiter=';', header=None,
                       names=['Timestamp', 'GPIO 3V6 DUT Oscillator (MHz)', 'GPIO 2V5 REF Oscillator (MHz)', 'GPIO 1V8 REF Oscillator (MHz)', 'Temperature (C)'],
                       parse_dates=['Timestamp'])

    # Strip whitespace from column names
    data.columns = data.columns.str.strip()
    if filter_out_osc_halt:
        dut_avg = data['GPIO 3V6 DUT Oscillator (MHz)'].mean()
        ref0_avg = data['GPIO 2V5 REF Oscillator (MHz)'].mean()
        ref1_avg = data['GPIO 1V8 REF Oscillator (MHz)'].mean()
        data = data[data['GPIO 3V6 DUT Oscillator (MHz)'] > dut_avg/2]
        data = data[data['GPIO 2V5 REF Oscillator (MHz)'] > ref0_avg/2]
        data = data[data['GPIO 1V8 REF Oscillator (MHz)'] > ref1_avg/2]
    data['GPIO 3V6 DUT Oscillator (MHz)'] = data['GPIO 3V6 DUT Oscillator (MHz)'] / 1e6
    data['GPIO 2V5 REF Oscillator (MHz)'] = data['GPIO 2V5 REF Oscillator (MHz)'] / 1e6
    data['GPIO 1V8 REF Oscillator (MHz)'] = data['GPIO 1V8 REF Oscillator (MHz)'] / 1e6

    # Plot the data
    fig, (ax1, axd0, axd1) = plt.subplots(3, sharex=True, height_ratios=[3,1,1])

    line1, = ax1.plot(data['Timestamp'], data['GPIO 3V6 DUT Oscillator (MHz)'], label='GPIO 3V6 DUT Oscillator (MHz)', color='b', linestyle='-', marker='')
    line2, = ax1.plot(data['Timestamp'], data['GPIO 2V5 REF Oscillator (MHz)'], label='GPIO 2V5 REF Oscillator (MHz)', color='r', linestyle='-', marker='')
    line3, = ax1.plot(data['Timestamp'], data['GPIO 1V8 REF Oscillator (MHz)'], label='GPIO 1V8 REF Oscillator (MHz)', color='y', linestyle='-', marker='')
    ax1.set_ylabel('Frequency (MHz)')
    ax1.grid(True)

    ax2 = ax1.twinx()
    line4, = ax2.plot(data['Timestamp'], data['Temperature (C)'], label='Temperature (C)', color='g', linestyle='-', linewidth=0.5, marker='')
    ax2.set_ylabel('Temperature (C)')
    ax2.set_ylim([20, 22])
    ax2.grid(False)

    difference = data['GPIO 3V6 DUT Oscillator (MHz)'] - data['GPIO 2V5 REF Oscillator (MHz)']
    line_diff, = axd0.plot(data['Timestamp'], difference,
                      label='Difference: REF - DUT (MHz)',
                      color='c',
                      linestyle='-', marker='')
    axd0.set_ylabel('Frequency (MHz)')
    axd0.grid(True)
    axd0.legend()

    difference = data['GPIO 2V5 REF Oscillator (MHz)'] - data['GPIO 1V8 REF Oscillator (MHz)']
    line_diff, = axd1.plot(data['Timestamp'], difference,
                      label='Difference: REF - REF (MHz)',
                      color='c',
                      linestyle='-', marker='')
    axd1.set_ylabel('Frequency (MHz)')
    axd1.grid(True)
    axd1.legend()

    # Merge legends
    lines = [line1, line2, line3, line4]
    labels = [line.get_label() for line in lines]
    ax1.legend(lines, labels)

    # Formatting the plot
    ax1.xaxis.set_major_formatter(mdates.DateFormatter('%Y-%m-%d %H:%M:%S'))
    plt.xlabel('Timestamp')
    plt.tight_layout()
    #plt.xticks(rotation=45)

    # Show the plot
    plt.show()

load_and_plot(sys.argv[1])
