#!/usr/bin/env python3
"""
Simple handshake test para JTAG UART con FPGA DE1-SoC
Requiere que tengas las herramientas de Quartus instaladas
"""

import subprocess
import time
import sys
import threading
import queue

class JTAGComm:
    def __init__(self):
        self.process = None
        self.output_queue = queue.Queue()
        self.input_queue = queue.Queue()
        self.running = False

        # Protocolo de handshake
        self.HELLO_BYTE = ord('H')  # 0x48
        self.ACK_BYTE = ord('A')    # 0x41
        self.READY_BYTE = ord('R')  # 0x52

    def start_jtag_uart(self):
        """Inicia la conexión JTAG UART usando nios2-terminal"""
        try:
            # Comando para conectar con JTAG UART
            cmd = ["/home/dylanggf/intelFPGA_lite/18.1/nios2eds/nios2_command_shell.sh", "--no-quit-on-ctrl-c", "--instance=0"]

            print("Iniciando conexión JTAG UART...")
            print(f"Comando: {' '.join(cmd)}")

            self.process = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=False,  # Trabajar con bytes
                bufsize=0  # Sin buffer
            )

            self.running = True

            # Iniciar threads para manejo de I/O
            self.output_thread = threading.Thread(target=self._read_output, daemon=True)
            self.input_thread = threading.Thread(target=self._write_input, daemon=True)

            self.output_thread.start()
            self.input_thread.start()

            print("✓ Conexión JTAG UART establecida")
            return True

        except FileNotFoundError:
            print("❌ Error: nios2-terminal no encontrado.")
            print("   Asegúrate de que las herramientas de Quartus estén en el PATH")
            return False
        except Exception as e:
            print(f"❌ Error al iniciar JTAG UART: {e}")
            return False

    def _read_output(self):
        """Thread para leer datos del JTAG UART"""
        while self.running and self.process:
            try:
                if self.process.stdout:
                    data = self.process.stdout.read(1)
                    if data:
                        self.output_queue.put(data[0])
            except Exception as e:
                print(f"Error leyendo JTAG: {e}")
                break

    def _write_input(self):
        """Thread para escribir datos al JTAG UART"""
        while self.running and self.process:
            try:
                if not self.input_queue.empty():
                    data = self.input_queue.get(timeout=0.1)
                    if self.process.stdin:
                        self.process.stdin.write(bytes([data]))
                        self.process.stdin.flush()
            except queue.Empty:
                continue
            except Exception as e:
                print(f"Error escribiendo JTAG: {e}")
                break

    def send_byte(self, byte_val):
        """Envía un byte a la FPGA"""
        self.input_queue.put(byte_val)
        print(f"→ Enviado: 0x{byte_val:02X} ('{chr(byte_val) if 32 <= byte_val <= 126 else '?'}')")

    def read_byte(self, timeout=1.0):
        """Lee un byte de la FPGA con timeout"""
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                byte_val = self.output_queue.get(timeout=0.1)
                char = chr(byte_val) if 32 <= byte_val <= 126 else '?'
                print(f"← Recibido: 0x{byte_val:02X} ('{char}')")
                return byte_val
            except queue.Empty:
                continue
        return None

    def perform_handshake(self):
        """Realiza el handshake con la FPGA"""
        print("\n🤝 Iniciando handshake...")

        # Paso 1: Enviar HELLO
        print(f"1. Enviando HELLO (0x{self.HELLO_BYTE:02X})...")
        self.send_byte(self.HELLO_BYTE)

        # Paso 2: Esperar ACK
        print("2. Esperando ACK de la FPGA...")
        received = self.read_byte(timeout=5.0)

        if received is None:
            print("❌ Timeout esperando ACK de la FPGA")
            return False

        if received == self.ACK_BYTE:
            print(f"✓ ACK recibido correctamente (0x{received:02X})")
            print("🎉 ¡Handshake completado exitosamente!")
            return True
        else:
            print(f"❌ Respuesta inesperada: 0x{received:02X}, esperaba ACK (0x{self.ACK_BYTE:02X})")
            return False

    def test_communication(self):
        """Prueba básica de comunicación"""
        print("\n📡 Probando comunicación...")

        # Enviar algunos bytes de prueba
        test_bytes = [0x11, 0x22, 0x33, 0x44]

        for test_byte in test_bytes:
            print(f"Enviando byte de prueba: 0x{test_byte:02X}")
            self.send_byte(test_byte)
            time.sleep(0.5)

        # Leer cualquier respuesta
        print("Leyendo respuestas...")
        for _ in range(5):
            received = self.read_byte(timeout=1.0)
            if received is None:
                break

    def close(self):
        """Cierra la conexión"""
        self.running = False
        if self.process:
            self.process.terminate()
            self.process.wait()
        print("✓ Conexión cerrada")

def main():
    print("=== Test de Comunicación JTAG UART con FPGA DE1-SoC ===")
    print("Asegúrate de que la FPGA esté programada y conectada via USB")

    comm = JTAGComm()

    try:
        # Iniciar conexión
        if not comm.start_jtag_uart():
            return 1

        # Esperar un momento para estabilizar
        print("Esperando estabilización...")
        time.sleep(2)

        # Realizar handshake
        if comm.perform_handshake():
            print("\n✅ Comunicación establecida correctamente")

            # Probar comunicación adicional
            comm.test_communication()

            # Mantener conexión abierta para pruebas manuales
            print("\n⌨️  Presiona Enter para enviar bytes manualmente (q para salir):")
            while True:
                try:
                    user_input = input("Enviar byte (hex, ej: 48): ").strip()
                    if user_input.lower() == 'q':
                        break

                    if user_input:
                        try:
                            byte_val = int(user_input, 16)
                            if 0 <= byte_val <= 255:
                                comm.send_byte(byte_val)
                                # Leer respuesta
                                response = comm.read_byte(timeout=2.0)
                                if response is None:
                                    print("Sin respuesta de la FPGA")
                            else:
                                print("Valor debe estar entre 0x00 y 0xFF")
                        except ValueError:
                            print("Formato inválido. Usa hexadecimal (ej: 48)")

                except KeyboardInterrupt:
                    break
        else:
            print("\n❌ Fallo en el handshake")
            return 1

    except KeyboardInterrupt:
        print("\n\n⏹️  Interrumpido por el usuario")
    except Exception as e:
        print(f"\n❌ Error inesperado: {e}")
        return 1
    finally:
        comm.close()

    return 0

if __name__ == "__main__":
    sys.exit(main())
