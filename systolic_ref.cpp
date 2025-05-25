#include <iostream>
#include <array>
#include <cstdint>
#include <iomanip>
#include <cassert>

// Dimensión del arreglo y tipo de datos
constexpr int N = 16;
using DataT = int16_t;      // 16-bit signed fixed-point
using AccT  = int32_t;      // Acumulador de 32 bits

// Simula la multiplicación de matrices (directa) como simplificación del flujo WS
void simulate_systolic(
    const std::array<std::array<DataT, N>, N> &A,
    const std::array<std::array<DataT, N>, N> &B,
    std::array<std::array<AccT, N>, N> &C)
{
    // Reiniciar y calcular C = A * B
    for(int i = 0; i < N; ++i) {
        for(int j = 0; j < N; ++j) {
            AccT sum = 0;
            for(int k = 0; k < N; ++k) {
                sum += static_cast<AccT>(A[i][k]) * static_cast<AccT>(B[k][j]);
            }
            C[i][j] = sum;
        }
    }
}

// Función de prueba para validar un caso 2x2
void test_case_2x2() {
    std::array<std::array<DataT, N>, N> A{};
    std::array<std::array<DataT, N>, N> B{};
    std::array<std::array<AccT, N>, N> C{};

    // Matrices de prueba 2x2
    A[0][0] = 1; A[0][1] = 2;
    A[1][0] = 3; A[1][1] = 4;
    B[0][0] = 5; B[0][1] = 6;
    B[1][0] = 7; B[1][1] = 8;

    simulate_systolic(A, B, C);

    // Resultados esperados
    assert(C[0][0] == 19);
    assert(C[0][1] == 22);
    assert(C[1][0] == 43);
    assert(C[1][1] == 50);

    std::cout << "[TEST 2x2] Pasó correctamente.\n";
}

int main() {
    // Matrices de ejemplo 16x16
    std::array<std::array<DataT, N>, N> A_main;
    std::array<std::array<DataT, N>, N> B_main;
    std::array<std::array<AccT,  N>, N> C_main{};

    for(int i = 0; i < N; ++i) {
        for(int j = 0; j < N; ++j) {
            A_main[i][j] = static_cast<DataT>(i + j);
            B_main[i][j] = static_cast<DataT>(i - j);
        }
    }

    // Ejecutar simulación principal
    simulate_systolic(A_main, B_main, C_main);

    // Imprimir matriz resultado
    std::cout << "Resultado C = A x B (16x16):\n";
    for(int i = 0; i < N; ++i) {
        for(int j = 0; j < N; ++j) {
            std::cout << std::setw(6) << C_main[i][j] << " ";
        }
        std::cout << "\n";
    }

    // Ejecutar prueba constante
    test_case_2x2();

    return 0;
}
