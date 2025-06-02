
---

# OFDM 通信系统仿真

本项目是一个基于 MATLAB 的OFDM（正交频分复用）通信系统仿真平台。它涵盖了OFDM系统的主要模块，包括前导码生成、OFDM帧构建、信道建模（衰落与AWGN）、定时同步、频域信道估计与均衡、QPSK解调以及误码率（BER）计算等。该平台旨在提供一个灵活的环境，用于研究不同系统参数、信道条件和信号处理算法对OFDM系统性能的影响。

# OFDM Communication System Simulation

This project is a MATLAB-based simulation platform for an OFDM (Orthogonal Frequency Division Multiplexing) communication system. It covers key modules of an OFDM system, including preamble generation, OFDM frame construction, channel modeling (fading and AWGN), timing synchronization, frequency-domain channel estimation and equalization, QPSK demodulation, and Bit Error Rate (BER) calculation. The platform aims to provide a flexible environment for studying the impact of different system parameters, channel conditions, and signal processing algorithms on OFDM system performance.

---

## 概述 (Overview)

本仿真项目包含多个 MATLAB 函数，每个函数负责OFDM链路中的一个特定环节。`Main.m` 脚本作为主驱动程序，演示了OFDM信号从发射到接收的完整流程，并支持对关键参数的配置。`Main_BERvsSNR.m` 则提供了一个框架，用于评估系统在不同信噪比（SNR）下的误码率性能。此外，项目还包括了针对各个模块的独立测试脚本，以确保其功能的正确性。

## Overview

This simulation project contains multiple MATLAB functions, each responsible for a specific stage in an OFDM link. The `Main.m` script serves as the primary driver, demonstrating the complete OFDM signal flow from transmission to reception, with support for configuring key parameters. `Main_BERvsSNR.m` provides a framework for evaluating the system's Bit Error Rate (BER) performance under varying Signal-to-Noise Ratio (SNR) conditions. Additionally, the project includes independent test scripts for various modules to ensure their correct functionality.

---

## 文件列表及功能 (File List and Functionality)

以下是本项目中所有文件及其主要功能的列表。每个文件的具体用途和详细参数可参考其内部的**头部注释**。

## File List and Functionality

Below is a list of all files in this project and their primary functions. For detailed usage and parameters of each file, please refer to its internal **header comments**.

* `active_indices_human_orderf.m`: 该函数用于计算和给出数学序列的子载波符号映射位置，确保在OFDM系统中正确地将数据或导频映射到活跃子载波上.
    * This function calculates and provides the subcarrier symbol mapping positions for mathematical sequences, ensuring that data or pilots are correctly mapped to active subcarriers in an OFDM system.
* `addAWGN.m`: 此函数用于给输入的信号添加指定信噪比（SNR）的加性高斯白噪声（AWGN），模拟实际通信中的噪声影响.
    * This function adds Additive White Gaussian Noise (AWGN) with a specified Signal-to-Noise Ratio (SNR) to the input signal, simulating the effects of noise in real communication.
* `buildPreamble.m`: 负责生成符合Schmidl-Cox类型的前导码，并包含循环前缀（CP）。它支持不同的CP模式和PN序列配置，用于接收端的同步和信道估计.
    * This function generates a Schmidl-Cox type preamble, including a Cyclic Prefix (CP). It supports different CP modes and PN sequence configurations, used for synchronization and channel estimation at the receiver.
* `decodeAndCalcBER.m`: 该函数在接收端执行比特解码（如果启用信道编码，如重复码），并计算接收到的比特流与原始发送比特流之间的误码率（BER）.
    * This function performs bit decoding at the receiver (if channel coding, such as repetition code, is enabled) and calculates the Bit Error Rate (BER) between the received bit stream and the original transmitted bit stream.
* `demapQPSK.m`: 用于对接收到的QPSK复数符号序列进行解映射，将其转换回原始的二进制比特流.
    * This function demaps the received QPSK complex symbol sequence, converting it back into the original binary bit stream.
* `generateOFDMDataFrame.m`: 此核心函数用于生成包含导频和数据信息的完整OFDM符号帧。它处理信源比特生成、可选的信道编码与交织、QPSK映射以及导频（Zadoff-Chu序列）的插入.
    * This core function generates a complete OFDM symbol frame containing pilot and data information. It handles source bit generation, optional channel coding and interleaving, QPSK mapping, and the insertion of pilot sequences (Zadoff-Chu sequences).
* `generateSymbolTypeSequence.m`: 根据预设的导频和数据符号模式（例如 P,D,D,D,D,P...），生成OFDM帧中每个符号的类型序列（"Pilot" 或 "Data"）.
    * This function generates a sequence of symbol types ("Pilot" or "Data") for each symbol in an OFDM frame, based on a predefined pilot and data symbol pattern (e.g., P,D,D,D,D,P...).
* `Main.m`: **主仿真脚本。** 该脚本是整个OFDM链路的端到端仿真入口，包含了参数配置、前导码生成、OFDM数据帧生成、信道模拟、定时同步、CP移除、频域处理、QPSK解调和BER计算等步骤，并提供可视化结果.
    * **Main Simulation Script.** This script is the end-to-end simulation entry point for the entire OFDM link, including parameter configuration, preamble generation, OFDM data frame generation, channel simulation, timing synchronization, CP removal, frequency-domain processing, QPSK demodulation, and BER calculation, providing visualized results.
* `Main_BERvsSNR.m`: **BER vs SNR 仿真脚本。** 此脚本提供了一个循环仿真框架，用于在不同信噪比条件下运行OFDM系统仿真，并绘制误码率（BER）与信噪比（SNR）的关系曲线，以评估系统性能.
    * **BER vs SNR Simulation Script.** This script provides a cyclical simulation framework for running OFDM system simulations under different SNR conditions and plotting the Bit Error Rate (BER) versus Signal-to-Noise Ratio (SNR) curve to evaluate system performance.
* `performFreqDomainProcessing.m`: 在接收端执行频域处理，包括FFT变换、基于导频的信道估计（LS估计）以及频域均衡（MMSE均衡），从而从频域信号中恢复数据符号.
    * This function performs frequency-domain processing at the receiver, including FFT transform, pilot-based channel estimation (LS estimation), and frequency-domain equalization (MMSE equalization), to recover data symbols from the frequency-domain signal.
* `removeCPForEachSymbol.m`: 用于从时域OFDM符号序列中移除循环前缀（CP），为后续的FFT变换做准备.
    * This function removes the Cyclic Prefix (CP) from the time-domain OFDM symbol sequence, preparing it for subsequent FFT transformation.
* `simulateCustomTDLChannel.m`: 该函数用于模拟自定义的或多径时延扩展（TDL）信道。它能够根据提供的信道参数（如径数、时延、功率）生成信道衰落，从而模拟无线传输环境.
    * This function simulates custom or Time-Delay Spread (TDL) channels. It can generate channel fading based on provided channel parameters (e.g., number of paths, delay, power) to simulate wireless transmission environments.
* `simulateUsingLTEFadingChannel.m`: 用于模拟符合LTE标准（3GPP TS 36.104）的衰落信道模型，例如ETU、EVA、EPA等，提供更真实的无线信道特性.
    * This function simulates fading channel models compliant with LTE standards (3GPP TS 36.104), such as ETU, EVA, EPA, etc., providing more realistic wireless channel characteristics.
* `symbolTimingSynchronizer.m`: 实现Schmidl-Cox定时同步算法，用于在接收端检测OFDM帧的起始位置，从而实现符号级同步.
    * This function implements the Schmidl-Cox timing synchronization algorithm, used at the receiver to detect the start of an OFDM frame, thereby achieving symbol-level synchronization.
* `Table B.2.1-1 Delay profiles for E-UTRA channel models.xlsx - Sheet1.csv`: 包含E-UTRA信道模型的通用时延分布（Delay profiles）数据.
    * Contains generic delay profile data for E-UTRA channel models.
* `Table B.2.1-2 Extended Pedestrian A model (EPA).xlsx - Sheet1.csv`: 包含扩展行人A（EPA）信道模型的详细参数，通常用于低速移动环境下的信道仿真.
    * Contains detailed parameters for the Extended Pedestrian A (EPA) channel model, typically used for channel simulation in low-speed mobile environments.
* `Table B.2.1-3 Extended Vehicular A model (EVA).xlsx - Sheet1.csv`: 包含扩展车载A（EVA）信道模型的详细参数，通常用于中高速移动环境下的信道仿真.
    * Contains detailed parameters for the Extended Vehicular A (EVA) channel model, typically used for channel simulation in medium to high-speed mobile environments.
* `Table B.2.1-4 Extended Typical Urban model (ETU).xlsx - Sheet1.csv`: 包含扩展典型城市（ETU）信道模型的详细参数，通常用于城市宏蜂窝环境下的信道仿真.
    * Contains detailed parameters for the Extended Typical Urban (ETU) channel model, typically used for channel simulation in urban macro-cell environments.
* `Table B.2.2-1 Channel model parameters.xlsx - Sheet1.csv`: 包含信道模型通用参数的表格数据，可能包括多普勒频移、最大时延等.
    * Contains tabular data for general channel model parameters, potentially including Doppler shift and maximum delay.
* `Test_buildPreamble.m`: 一个独立的测试脚本，用于验证 `buildPreamble.m` 函数的功能和输出，确保前导码生成模块的正确性.
    * An independent test script to verify the functionality and output of the `buildPreamble.m` function, ensuring the correctness of the preamble generation module.
* `Test_channel.m`: 一个独立的测试脚本，用于验证信道模拟相关函数（例如 `simulateUsingLTEFadingChannel.m` 或 `simulateCustomTDLChannel.m`）的功能和行为.
    * An independent test script to verify the functionality and behavior of channel simulation-related functions (e.g., `simulateUsingLTEFadingChannel.m` or `simulateCustomTDLChannel.m`).
* `testgenerateOFDMdata.m`: 一个独立的测试脚本，用于验证 `generateOFDMDataFrame.m` 函数生成OFDM数据帧的正确性，包括数据映射和导频插入等方面.
    * An independent test script to verify the correctness of the `generateOFDMDataFrame.m` function in generating OFDM data frames, including aspects such as data mapping and pilot insertion.

---

## 依赖 (Dependencies)

本项目主要依赖于 MATLAB 环境及其内置函数。部分功能可能需要 MATLAB 的特定工具箱，例如：

## Dependencies

This project primarily relies on the MATLAB environment and its built-in functions. Some functionalities may require specific MATLAB toolboxes, such as:

* **Communications Toolbox™**: 用于 `awgn` (在 `addAWGN.m` 中), `qammod`, `qamdemod` (在 `generateOFDMDataFrame.m` 和 `demapQPSK.m` 中).
    * Used for `awgn` (in `addAWGN.m`), `qammod`, `qamdemod` (in `generateOFDMDataFrame.m` and `demapQPSK.m`).
* **LTE Toolbox™**: 可能用于某些符合LTE标准的信道模型功能 (例如在 `simulateUsingLTEFadingChannel.m` 中)，或者处理LTE特定的信号结构.
    * Potentially used for certain LTE-compliant channel model functionalities (e.g., in `simulateUsingLTEFadingChannel.m`) or for processing LTE-specific signal structures.
* **DSP System Toolbox™**: 可能用于信号处理、滤波或FFT/IFFT等优化功能.
    * Potentially used for signal processing, filtering, or optimized FFT/IFFT functions.

请确保您的 MATLAB 环境已安装并激活了上述工具箱。

Please ensure that your MATLAB environment has the above toolboxes installed and activated.

---

## 使用方法 (Usage)

1.  **打开 MATLAB**: 启动 MATLAB 应用程序。
    * **Open MATLAB**: Launch the MATLAB application.
2.  **导航到项目目录**: 在 MATLAB 的当前文件夹浏览器中，导航到您存放本项目文件的目录。
    * **Navigate to Project Directory**: In MATLAB's current folder browser, navigate to the directory where you have stored the project files.
3.  **运行仿真**:
    * **Run Simulation**:
    * 要运行单次端到端仿真并查看详细过程及可视化结果，请运行 `Main.m` 脚本：
        ```matlab
        Main
        ```
        您可以在 `Main.m` 文件的开头配置仿真参数，如子载波数、CP模式、SNR等。
        * To run a single end-to-end simulation and view detailed processes and visualization results, run the `Main.m` script:
            ```matlab
            Main
            ```
            You can configure simulation parameters such as subcarrier number, CP mode, SNR, etc., at the beginning of the `Main.m` file.
    * 要生成 BER vs SNR 曲线以评估系统性能，请运行 `Main_BERvsSNR.m` 脚本：
        ```matlab
        Main_BERvsSNR
        ```
        该脚本将遍历一系列预设的SNR值，并绘制相应的BER曲线。
        * To generate a BER vs SNR curve to evaluate system performance, run the `Main_BERvsSNR.m` script:
            ```matlab
            Main_BERvsSNR
            ```
            This script will iterate through a series of predefined SNR values and plot the corresponding BER curve.
    * 要单独测试前导码生成功能，请运行 `Test_buildPreamble.m`。
        * To test the preamble generation function independently, run `Test_buildPreamble.m`.
    * 要单独测试信道模拟功能，请运行 `Test_channel.m`。
        * To test the channel simulation function independently, run `Test_channel.m`.
    * 要单独测试OFDM数据帧生成功能，请运行 `testgenerateOFDMdata.m`。
        * To test the OFDM data frame generation function independently, run `testgenerateOFDMdata.m`.

**重要提示：** 每个 MATLAB 函数的详细用法、输入/输出格式以及可能接受的参数，请务必参阅其**头部注释**。

**Important Note:** For detailed usage, input/output formats, and any accepted parameters for each MATLAB function, please refer to its **header comments**.

---

## 如何贡献 (How to Contribute)

我们欢迎任何形式的贡献，包括但不限于：

## How to Contribute

We welcome contributions of any kind, including but not limited to:

* 报告 Bug
    * Reporting Bugs
* 提交功能请求
    * Submitting Feature Requests
* 改进代码或文档
    * Improving Code or Documentation

请遵循以下步骤：

Please follow these steps:

1.  Fork 本仓库。
    * Fork this repository.
2.  创建您的功能分支 (`git checkout -b feature/AmazingFeature`)。
    * Create your feature branch (`git checkout -b feature/AmazingFeature`).
3.  提交您的更改 (`git commit -m 'Add some AmazingFeature'`)。
    * Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4.  推送到分支 (`git push origin feature/AmazingFeature`)。
    * Push to the branch (`git push origin feature/AmazingFeature`).
5.  打开一个 Pull Request。
    * Open a Pull Request.

---

## 许可证 (License)

本项目采用 MIT 许可证。更多详情请参见 `LICENSE` 文件（如果存在）。

## License

This project is licensed under the MIT License. See the `LICENSE` file (if present) for more details.

---

## 联系方式 (Contact)

如果您有任何问题或建议，欢迎联系：

## Contact

If you have any questions or suggestions, feel free to contact:

* GitHub: [RageWitness](https://github.com/RageWitness)

---
