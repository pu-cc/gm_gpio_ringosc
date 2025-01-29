import matplotlib.pyplot as plt
import pandas as pd

def load_and_plot(file_path):
    data = pd.read_csv(file_path, delimiter=';', header=None,
                       names=['Timestamp', 'GPIO Under Test (MHz)', 'GPIO Reference (MHz)', 'DUT Voltage (V)'],
                       parse_dates=['Timestamp'])

    # Strip whitespace from column names
    data.columns = data.columns.str.strip()
    data['GPIO Under Test (MHz)'] = data['GPIO Under Test (MHz)'] / 1e6
    data['GPIO Reference (MHz)'] = data['GPIO Reference (MHz)'] / 1e6

    # Plot the data
    fig, ax1 = plt.subplots(figsize=(10, 6))

    line1, = ax1.plot(data['Timestamp'], data['GPIO Under Test (MHz)'], label='GPIO Under Test (MHz)', color='b', linestyle='-', marker='')
    line2, = ax1.plot(data['Timestamp'], data['GPIO Reference (MHz)'], label='GPIO Reference (MHz)', color='r', linestyle='-', marker='')
    ax1.set_xlabel('Timestamp')
    ax1.set_ylabel('Frequency (MHz)')
    ax1.grid(True)

    ax2 = ax1.twinx()
    line3, = ax2.plot(data['Timestamp'], data['DUT Voltage (V)'], label='DUT Voltage (V)', color='y', linestyle='-', marker='')
    ax2.set_ylabel('DUT Voltage (V)')
    ax2.grid(True)

    # Merge legends
    lines = [line1, line2, line3]
    labels = [line.get_label() for line in lines]
    ax1.legend(lines, labels)

    # Formatting the plot
    plt.xlabel('Timestamp')
    plt.tight_layout()
    plt.xticks(rotation=45)

    # Show the plot
    plt.show()

load_and_plot('../db/stress_6v_uart_data2025-01-21_23-59-11.txt')
