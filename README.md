# jupyter multilangs

Jupyter lab docker image for various languages. Partial fork of [HeRoMo/jupyter-langs] (https://github.com/HeRoMo/jupyter-langs)

## Support languages:

1. Python (v3.10)
2. C# (dotnet v7.0)
3. F# (dotnet v7.0)
4. Elixir (v1.12.3)
5. Erlang (v1.12.3)
6. Go (v1.20.5)
7. Java (v21)
8. JavaScript (NodeJS) (v20)
9. TypeScript
10. Julia (v1.9.1)
11. PowerShell (dotnet v7.0)
12. R
13. Ruby (v3.2.2)
14. Rust (v1.70.0)
15. Scala (v2.13.8)
16. Sparql
17. C++11
18. C++14
19. C++17
20. Haskell

## Installed widgets:

* jupyterlab-git
* jupyterlab-lsp
* @krassowski/jupyterlab_go_to_definition
* jupyterlab-plotly
* jupyter_dash
* ipydrawio

## Installed language pack:

* ru-RU

## Installed language servers:

1. Python (jedi-language-server)
2. Julia
3. Bash (bash-language-server)

## Python library in main (Python3) kernels

- Sympy
- Numpy
- Scipy
- Pandas
- Matplotlib
- keras
- torch

## Additional kernels

- python_evtx (for python3.10 with python-evtx library)
- impacket (for python3.10 with impacket and scapy)

## Building

For build this image just clone this Repo and run:
```bash
$ docker build . -t jupyter:multilang
```

## Usage

For using this image run:
```bash
$ docker volume create jupyterlab
$ docker run -d -p 8888:8888 \
$     -v jupyterlab:/jupyterlab
$     jupyter:multilang
```

After starting container, you can access http://localhost:8888/jupyter/ to open jupyter lab
