docker run -it --rm --entrypoint "" \
     -v P4-IPG-HH:/workspace \
     -w /workspace p4lang/p4runtime-sh:latest bash \
     -c "source /p4runtime-sh/venv/bin/activate; \
     export PYTHONPATH=/p4runtime-sh:/p4runtime-sh/py_out; \
     python3 -c 'import p4runtime_sh.shell as sh'; \
     python3 p4rt/p4rt.py" \
