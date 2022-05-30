# Compiler 2022 Programming Assignment III
μGO Compiler for Java Assembly Code Generation

## 作業介紹
This assignment is to generate Java assembly code (for Java Virtual Machines) of the given μGO
program. The generated code will then be translated to the Java bytecode by the Java assembler,
Jasmin. The generated Java bytecode should be run by the Java Virtual Machine (JVM) successfully.

## 系統環境設定
Recommended OS: Ubuntu 18.04
Install dependencies:  ```$ sudo apt install flex bison```
Java Virtual Machine (JVM):  ```$ sudo apt install default-jre```
Java Assembler (Jasmin) is included in the Compiler hw3 le.
Judgmental tool:  
```$ pip3 install local-judge```

### 安裝助教的judge程式
```python
pip3 install local-judge
```
### judge方式
typing judge in your terminal.
```shell
$ judge
```