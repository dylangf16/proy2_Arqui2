#include <iostream>
#include <array>
#include <cstdint>
#include <iomanip>
#include <cassert>

// Dimensión del arreglo (8×8 PEs)
constexpr int N = 8;
using DataT = int16_t;   // 16-bit signed fixed-point
using AccT  = int32_t;   // Acumulador de 32 bits

// Alias para las tres matrices
using MatA = std::array<std::array<DataT, N>, N>;
using MatB = std::array<std::array<DataT, N>, N>;
using MatC = std::array<std::array<AccT,  N>, N>;

// Cada Processing Element guarda su a, b y suma parcial
struct PE {
    DataT a = 0, b = 0;
    AccT  psum = 0;
};

// Función auxiliar para imprimir una matriz
template<typename T>
void print_mat(const std::array<std::array<T,N>,N>& M, char name) {
    std::cout << "   Mat " << name << ":\n";
    for(int i=0;i<N;++i) {
        std::cout << "    ";
        for(int j=0;j<N;++j)
            std::cout << std::setw(6) << M[i][j] << ' ';
        std::cout << "\n";
    }
    std::cout << "\n";
}

// Simula la multiplicación de matrices A×B usando un arreglo sistólico NxN
void simulate_systolic(const MatA& A, const MatB& B, MatC& C, bool debug=false) {
    std::array<std::array<PE,N>,N> mesh{};
    int total_cycles = 3*N - 2;

    for(int t=0; t<total_cycles; ++t) {
        // inyecta A en columna 0 / B en fila 0 (ó ceros)
        for(int i=0;i<N;++i) {
            int k = t - i;
            mesh[i][0].a = (0<=k && k<N) ? A[i][k] : 0;
        }
        for(int j=0;j<N;++j) {
            int k = t - j;
            mesh[0][j].b = (0<=k && k<N) ? B[k][j] : 0;
        }

        // buffers para shift
        std::array<std::array<DataT,N>,N> nextA{};
        std::array<std::array<DataT,N>,N> nextB{};

        // cada PE multiplica y acumula, y programa su shift
        for(int i=0;i<N;++i){
            for(int j=0;j<N;++j){
                auto &pe = mesh[i][j];
                pe.psum += AccT(pe.a)*AccT(pe.b);
                if(j+1<N) nextA[i][j+1] = pe.a;
                if(i+1<N) nextB[i+1][j] = pe.b;
            }
        }
        // actualiza a/b
        for(int i=0;i<N;++i)
            for(int j=0;j<N;++j){
                mesh[i][j].a = nextA[i][j];
                mesh[i][j].b = nextB[i][j];
            }

            if (debug) {
                // extraer tres matrices auxiliares para imprimir
                std::array<std::array<DataT,N>,N> MA{}, MB{};
                std::array<std::array<AccT, N>,N>  MP{};
                for(int i=0;i<N;++i)
                    for(int j=0;j<N;++j){
                        MA[i][j] = mesh[i][j].a;
                        MB[i][j] = mesh[i][j].b;
                        MP[i][j] = mesh[i][j].psum;
                    }
                    std::cout << "=== Cycle t="<<t<<" ===\n";
                print_mat(MA,'A');
                print_mat(MB,'B');
                print_mat(MP,'P');
            }
    }

    // vuelca resultados
    for(int i=0;i<N;++i)
        for(int j=0;j<N;++j)
            C[i][j] = mesh[i][j].psum;
}

int main() {
    // Matrices hardcodeadas para prueba de 8×8
    constexpr MatA A = {{
        {{  1,  2,  3,  4,  5,  6,  7,  8 }},
        {{  9, 10, 11, 12, 13, 14, 15, 16 }},
        {{ 17, 18, 19, 20, 21, 22, 23, 24 }},
        {{ 25, 26, 27, 28, 29, 30, 31, 32 }},
        {{ 33, 34, 35, 36, 37, 38, 39, 40 }},
        {{ 41, 42, 43, 44, 45, 46, 47, 48 }},
        {{ 49, 50, 51, 52, 53, 54, 55, 56 }},
        {{ 57, 58, 59, 60, 61, 62, 63, 64 }}
    }};

    constexpr MatB B = {{
        {{ 64, 63, 62, 61, 60, 59, 58, 57 }},
        {{ 56, 55, 54, 53, 52, 51, 50, 49 }},
        {{ 48, 47, 46, 45, 44, 43, 42, 41 }},
        {{ 40, 39, 38, 37, 36, 35, 34, 33 }},
        {{ 32, 31, 30, 29, 28, 27, 26, 25 }},
        {{ 24, 23, 22, 21, 20, 19, 18, 17 }},
        {{ 16, 15, 14, 13, 12, 11, 10,  9 }},
        {{  8,  7,  6,  5,  4,  3,  2,  1 }}
    }};

    // Resultado teórico de A x B
    constexpr MatC C_expected = {{
        {{  960,   924,   888,   852,   816,   780,   744,   708 }},
        {{ 3264,  3164,  3064,  2964,  2864,  2764,  2664,  2564 }},
        {{ 5568,  5404,  5240,  5076,  4912,  4748,  4584,  4420 }},
        {{ 7872,  7644,  7416,  7188,  6960,  6732,  6504,  6276 }},
        {{10176,  9884,  9592,  9300,  9008,  8716,  8424,  8132 }},
        {{12480, 12124, 11768, 11412, 11056, 10700, 10344,  9988 }},
        {{14784, 14364, 13944, 13524, 13104, 12684, 12264, 11844 }},
        {{17088, 16604, 16120, 15636, 15152, 14668, 14184, 13700 }}
    }};

    MatC C;
    simulate_systolic(A, B, C, /*debug=*/true);

    // Comparar cada elemento con el resultado esperado
    for (int i = 0; i < N; ++i)
        for (int j = 0; j < N; ++j)
            assert(C[i][j] == C_expected[i][j]);

    std::cout << "[TEST 8×8 Hardcode] Pasó correctamente.\n";
    return 0;
}
