# Makefile para compilar handshake.c
# Cliente que usa nios2-terminal para comunicarse con FPGA

CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -D_GNU_SOURCE
TARGET = handshake
SOURCE = handshake.c

# Ruta del Nios II EDS (ajustar si es diferente) hacer nios2-terminal
NIOS2_EDS_PATH = /home/dylanggf/intelFPGA_lite/18.1/nios2eds/

# Regla principal
$(TARGET): $(SOURCE)
	$(CC) $(CFLAGS) -o $(TARGET) $(SOURCE)
	@echo "Compilación exitosa."
	@echo ""
	@echo "IMPORTANTE: Para ejecutar correctamente:"
	@echo "1. Asegúrate de que la FPGA esté programada"
	@echo "2. Verifica que el cable JTAG esté conectado"
	@echo "3. Ejecuta: ./$(TARGET)"

# Alias para build
build: $(TARGET)

# Limpiar archivos compilados
clean:
	rm -f $(TARGET)
	@echo "Archivos limpiados"

# Verificar entorno Nios II EDS
check-nios2:
	@echo "Verificando entorno Nios II EDS..."
	@if [ -d "$(NIOS2_EDS_PATH)" ]; then \
		echo "✓ Directorio Nios II EDS encontrado: $(NIOS2_EDS_PATH)"; \
	else \
		echo "✗ ERROR: No se encontró $(NIOS2_EDS_PATH)"; \
		echo "  Edita NIOS2_EDS_PATH en el Makefile con la ruta correcta"; \
		exit 1; \
	fi
	@if [ -f "$(NIOS2_EDS_PATH)/bin/nios2-terminal" ]; then \
		echo "✓ nios2-terminal encontrado"; \
	else \
		echo "✗ ERROR: nios2-terminal no encontrado en $(NIOS2_EDS_PATH)/bin/"; \
		exit 1; \
	fi
	@echo "✓ Entorno Nios II EDS verificado correctamente"

# Ejecutar con verificaciones
run: $(TARGET) check-nios2
	@echo "Ejecutando cliente handshake..."
	./$(TARGET)

# Mostrar información del sistema JTAG
jtag-info:
	@echo "=== Información del sistema JTAG ==="
	@if [ -d "$(NIOS2_EDS_PATH)" ]; then \
		cd $(NIOS2_EDS_PATH) && ./bin/jtagconfig; \
	else \
		echo "No se puede acceder a jtagconfig - verifica NIOS2_EDS_PATH"; \
	fi

# Probar nios2-terminal manualmente
test-terminal:
	@echo "Iniciando nios2-terminal manualmente..."
	@echo "Presiona Ctrl+C para salir"
	cd $(NIOS2_EDS_PATH) && ./bin/nios2-terminal

# Mostrar ayuda
help:
	@echo "Comandos disponibles:"
	@echo "  make handshake     - Compilar el programa"
	@echo "  make build         - Compilar el programa (alias)"
	@echo "  make run           - Compilar y ejecutar con verificaciones"
	@echo "  make check-nios2   - Verificar entorno Nios II EDS"
	@echo "  make jtag-info     - Mostrar información JTAG"
	@echo "  make test-terminal - Probar nios2-terminal manualmente"
	@echo "  make clean         - Limpiar archivos compilados"
	@echo "  make help          - Mostrar esta ayuda"
	@echo ""
	@echo "Flujo recomendado:"
	@echo "1. make check-nios2  (verificar entorno)"
	@echo "2. make jtag-info    (verificar conexión JTAG)"
	@echo "3. make run          (compilar y ejecutar)"

.PHONY: clean check-nios2 run jtag-info test-terminal help build
