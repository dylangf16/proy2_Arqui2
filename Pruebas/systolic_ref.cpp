#include <iostream>
#include <array>
#include <cstdint>
#include <iomanip>
#include <cassert>

// Dimensión del arreglo (8×8 PEs)
constexpr int N = 8;
using DataT = int16_t;   // 16-bit signed fixed-point
using AccT  = int32_t;   // acumulador de 32 bits

// Alias para las tres matrices
typedef std::array<std::array<DataT, N>, N> MatA;
typedef std::array<std::array<DataT, N>, N> MatB;
typedef std::array<std::array<AccT,  N>, N> MatC;

// Cada Processing Element guarda su a, b y suma parcial
struct PE {
    DataT a = 0, b = 0;
    AccT  psum = 0;
};

// Función auxiliar para imprimir una matriz
template<typename T>
void print_mat(const std::array<std::array<T,N>,N>& M, char name) {
    std::cout << "   Mat " << name << ":\n";
    for(int i = 0; i < N; ++i) {
        std::cout << "    ";
        for(int j = 0; j < N; ++j)
            std::cout << std::setw(6) << M[i][j] << ' ';
        std::cout << "\n";
    }
    std::cout << "\n";
}

// Simula la multiplicación A×B usando un arreglo sistólico N×N
void simulate_systolic(const MatA& A, const MatB& B, MatC& C, bool debug=false) {
    std::array<std::array<PE,N>,N> mesh{};
    int total_cycles = 3*N - 2;

    for(int t = 0; t < total_cycles; ++t) {
        // inyecta A en columna 0 / B en fila 0 (o ceros fuera de rango)
        for(int i = 0; i < N; ++i) {
            int k = t - i;
            mesh[i][0].a = (0 <= k && k < N) ? A[i][k] : 0;
        }
        for(int j = 0; j < N; ++j) {
            int k = t - j;
            mesh[0][j].b = (0 <= k && k < N) ? B[k][j] : 0;
        }

        // buffers para el shift
        std::array<std::array<DataT,N>,N> nextA{};
        std::array<std::array<DataT,N>,N> nextB{};

        // cada PE multiplica y acumula
        for(int i = 0; i < N; ++i) {
            for(int j = 0; j < N; ++j) {
                auto &pe = mesh[i][j];
                pe.psum += AccT(pe.a) * AccT(pe.b);
                if (j+1 < N) nextA[i][j+1] = pe.a;
                if (i+1 < N) nextB[i+1][j] = pe.b;
            }
        }
        // actualiza registros a/b
        for(int i = 0; i < N; ++i)
            for(int j = 0; j < N; ++j) {
                mesh[i][j].a = nextA[i][j];
                mesh[i][j].b = nextB[i][j];
            }

        if (debug) {
            std::array<std::array<DataT,N>,N> MA{}, MB{};
            std::array<std::array<AccT,N>,N> MP{};
            for(int i = 0; i < N; ++i) {
                for(int j = 0; j < N; ++j) {
                    MA[i][j] = mesh[i][j].a;
                    MB[i][j] = mesh[i][j].b;
                    MP[i][j] = mesh[i][j].psum;
                }
            }
            std::cout << "=== Cycle t="<< t << " ===\n";
            print_mat(MA,'A'); // Valores de A inyectados en la malla
            print_mat(MB,'B'); // Valores de B inyectados en la malla
            print_mat(MP,'C'); // Sumas parciales (matriz C en formación)
        }
    }

    // vuelca resultados finales
    for(int i = 0; i < N; ++i)
        for(int j = 0; j < N; ++j)
            C[i][j] = mesh[i][j].psum;
}

int main() {
    MatA A{};
    // Matriz A: diagonal con 5s
    for(int i = 0; i < N; ++i)
        for(int j = 0; j < N; ++j)
            A[i][j] = (i == j) ? DataT(5) : DataT(0);

    // Matriz B: estática, primera columna con "CIPHER" y resto valores fijos
    MatB B = {{
        { 2, 10, 20, 30, 40, 50, 60, 70 },
        { 8, 11, 21, 31, 41, 51, 61, 71 },
        { 15,12, 22, 32, 42, 52, 62, 72 },
        { 7, 13, 23, 33, 43, 53, 63, 73 },
        { 4, 14, 24, 34, 44, 54, 64, 74 },
        { 17,15, 25, 35, 45, 55, 65, 75 },
        { 6, 16, 26, 36, 46, 56, 66, 76 },
        { 9, 18, 28, 38, 48, 58, 68, 78 }
    }};

    MatC C{};

    // Imprime A y B iniciales
    print_mat(A,'A');
    print_mat(B,'B');

    // Ejecuta la simulación con debug para imprimir en cada ciclo
    simulate_systolic(A, B, C, true);

    // Imprime la matriz resultante C
    print_mat(C,'C');

    std::cout << "[SIMULACIÓN COMPLETA]" << std::endl;
    return 0;
}
