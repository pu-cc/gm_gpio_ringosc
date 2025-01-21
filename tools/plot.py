import matplotlib.pyplot as plt
import pandas as pd

def load_and_plot(file_path):
    data = pd.read_csv(file_path, delimiter=';', header=None,
                       names=['Timestamp', 'GPIO Under Test (MHz)', 'GPIO Reference (MHz)'],
                       parse_dates=['Timestamp'])

    # Strip whitespace from column names
    data.columns = data.columns.str.strip()
    data['GPIO Under Test (MHz)'] = data['GPIO Under Test (MHz)'] / 1e6
    data['GPIO Reference (MHz)'] = data['GPIO Reference (MHz)'] / 1e6

    # Plot the data
    plt.figure(figsize=(10, 6))
    plt.plot(data['Timestamp'], data['GPIO Under Test (MHz)'], label='GPIO Under Test (MHz)', color='b', linestyle='-', marker='')
    plt.plot(data['Timestamp'], data['GPIO Reference (MHz)'], label='GPIO Reference (MHz)', color='r', linestyle='-', marker='')

    # Formatting the plot
    plt.xlabel('Timestamp')
    plt.ylabel('Frequency (MHz)')
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    plt.xticks(rotation=45)

    # Show the plot
    plt.show()

load_and_plot('../db/stress_6v_uart_data2025-01-21_23-59-11.txt')
