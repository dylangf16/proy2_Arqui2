/*
 * handshake.c - Cliente para realizar handshake con FPGA via nios2-terminal
 * Debe ejecutarse desde el entorno Nios II EDS
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/select.h>
#include <sys/time.h>
#include <signal.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>

#define NIOS2_EDS_PATH "/home/dylanggf/intelFPGA_lite/18.1/nios2eds/"
#define HANDSHAKE_MSG "HELLO_FPGA\n"
#define RESPONSE_EXPECTED "Handshake recibido"

// Variables globales para manejo de proceso
pid_t nios2_terminal_pid = -1;
int pipe_to_nios2[2];   // Para escribir al nios2-terminal
int pipe_from_nios2[2]; // Para leer del nios2-terminal

void cleanup_and_exit(int sig) {
    (void)sig; // Suprimir warning de parámetro no usado
    printf("\n=== Terminando conexión ===\n");

    if (nios2_terminal_pid > 0) {
        printf("Cerrando nios2-terminal...\n");
        kill(nios2_terminal_pid, SIGTERM);
        waitpid(nios2_terminal_pid, NULL, 0);
    }

    // Cerrar pipes
    close(pipe_to_nios2[0]);
    close(pipe_to_nios2[1]);
    close(pipe_from_nios2[0]);
    close(pipe_from_nios2[1]);

    printf("Conexión cerrada\n");
    exit(0);
}

int setup_nios2_terminal() {
    char nios2_terminal_path[512];

    printf("=== Configurando entorno Nios II EDS ===\n");

    // Crear pipes para comunicación bidireccional
    if (pipe(pipe_to_nios2) < 0 || pipe(pipe_from_nios2) < 0) {
        perror("Error creando pipes");
        return -1;
    }

    // Construir ruta completa del nios2-terminal
    snprintf(nios2_terminal_path, sizeof(nios2_terminal_path),
             "%s/bin/nios2-terminal", NIOS2_EDS_PATH);

    printf("Iniciando nios2-terminal desde: %s\n", nios2_terminal_path);

    // Fork para crear proceso hijo
    nios2_terminal_pid = fork();

    if (nios2_terminal_pid < 0) {
        perror("Error en fork");
        return -1;
    }

    if (nios2_terminal_pid == 0) {
        // Proceso hijo - ejecutar nios2-terminal

        // Redirigir stdin del hijo al pipe de escritura
        dup2(pipe_to_nios2[0], STDIN_FILENO);
        close(pipe_to_nios2[1]);

        // Redirigir stdout del hijo al pipe de lectura
        dup2(pipe_from_nios2[1], STDOUT_FILENO);
        dup2(pipe_from_nios2[1], STDERR_FILENO);
        close(pipe_from_nios2[0]);

        // Cambiar al directorio de Nios II EDS
        if (chdir(NIOS2_EDS_PATH) < 0) {
            perror("Error cambiando directorio");
            exit(1);
        }

        // Configurar variables de entorno
        setenv("PATH", NIOS2_EDS_PATH "bin:" NIOS2_EDS_PATH "bin/gnu/H-x86_64-pc-linux-gnu/bin", 1);
        setenv("QUARTUS_ROOTDIR", "/home/dylanggf/intelFPGA_lite/18.1/quartus", 1);

        // Ejecutar nios2-terminal
        execl(nios2_terminal_path, "nios2-terminal", NULL);

        // Si llegamos aquí, hubo error
        perror("Error ejecutando nios2-terminal");
        exit(1);
    }

    // Proceso padre
    close(pipe_to_nios2[0]);   // No necesitamos leer de aquí
    close(pipe_from_nios2[1]); // No necesitamos escribir aquí

    // Hacer el pipe de lectura no-bloqueante
    int flags = fcntl(pipe_from_nios2[0], F_GETFL);
    fcntl(pipe_from_nios2[0], F_SETFL, flags | O_NONBLOCK);

    printf("nios2-terminal iniciado (PID: %d)\n", nios2_terminal_pid);
    printf("Esperando que se establezca la conexión JTAG...\n");

    sleep(3); // Dar tiempo para que se establezca la conexión

    return 0;
}

int send_to_fpga(const char* message) {
    int bytes_written = write(pipe_to_nios2[1], message, strlen(message));
    if (bytes_written < 0) {
        perror("Error enviando mensaje a FPGA");
        return -1;
    }

    printf("Enviado a FPGA: '%s' (%d bytes)\n", message, bytes_written);
    return bytes_written;
}

int read_from_fpga(char* buffer, int buffer_size, int timeout_sec) {
    fd_set readfs;
    struct timeval timeout;
    int total_bytes = 0;

    memset(buffer, 0, buffer_size);

    time_t start_time = time(NULL);

    while ((time(NULL) - start_time) < timeout_sec) {
        FD_ZERO(&readfs);
        FD_SET(pipe_from_nios2[0], &readfs);
        timeout.tv_sec = 1;
        timeout.tv_usec = 0;

        int retval = select(pipe_from_nios2[0] + 1, &readfs, NULL, NULL, &timeout);

        if (retval > 0) {
            int bytes_read = read(pipe_from_nios2[0], buffer + total_bytes,
                                  buffer_size - total_bytes - 1);

            if (bytes_read > 0) {
                total_bytes += bytes_read;
                buffer[total_bytes] = '\0';

                // Verificar si hemos recibido el mensaje completo
                if (strstr(buffer, RESPONSE_EXPECTED) != NULL) {
                    return total_bytes;
                }
            }
        }

        usleep(100000); // 100ms
    }

    return total_bytes;
}

int main() {
    char buffer[1024];
    int bytes_read;

    printf("=== Cliente Handshake FPGA - Nios II EDS ===\n");
    printf("Ruta Nios II EDS: %s\n", NIOS2_EDS_PATH);

    // Configurar handler para limpieza
    signal(SIGINT, cleanup_and_exit);
    signal(SIGTERM, cleanup_and_exit);

    // Verificar que existe el directorio Nios II EDS
    if (access(NIOS2_EDS_PATH, F_OK) != 0) {
        printf("Error: No se encontró el directorio Nios II EDS en: %s\n", NIOS2_EDS_PATH);
        printf("Verifica la ruta en el código fuente\n");
        return -1;
    }

    // Configurar nios2-terminal
    if (setup_nios2_terminal() < 0) {
        printf("Error configurando nios2-terminal\n");
        return -1;
    }

    printf("\n=== Iniciando Handshake ===\n");

    // Enviar mensaje de handshake
    printf("Enviando mensaje de handshake...\n");
    if (send_to_fpga(HANDSHAKE_MSG) < 0) {
        cleanup_and_exit(1);
        return -1;
    }

    // Esperar respuesta
    printf("Esperando respuesta de la FPGA (timeout: 15 segundos)...\n");
    bytes_read = read_from_fpga(buffer, sizeof(buffer), 15);

    if (bytes_read > 0) {
        printf("✓ Respuesta recibida (%d bytes):\n", bytes_read);
        printf("'%s'\n", buffer);

        if (strstr(buffer, RESPONSE_EXPECTED) != NULL) {
            printf("✓ ¡Handshake completado exitosamente!\n");
            printf("✓ La FPGA confirmó: '%s'\n", RESPONSE_EXPECTED);
        } else {
            printf("⚠ Respuesta inesperada de la FPGA\n");
        }
    } else {
        printf("✗ Timeout: No se recibió respuesta de la FPGA\n");
        printf("Verifica que:\n");
        printf("1. La FPGA esté programada correctamente\n");
        printf("2. El cable JTAG esté conectado\n");
        printf("3. El módulo jtag_uart esté funcionando\n");
    }

    // Continuar escuchando mensajes
    printf("\n=== Escuchando mensajes continuos ===\n");
    printf("(Presiona Ctrl+C para salir)\n");

    while (1) {
        bytes_read = read_from_fpga(buffer, sizeof(buffer), 2);

        if (bytes_read > 0) {
            // Filtrar mensajes de nios2-terminal
            if (strstr(buffer, "nios2-terminal") == NULL &&
                strstr(buffer, "Connected to") == NULL) {
                printf("FPGA: %s", buffer);
            fflush(stdout);
                }
        }

        sleep(1);
    }

    cleanup_and_exit(0);
    return 0;
}
