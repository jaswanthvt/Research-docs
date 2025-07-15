

## ✅ Modular Design

### 🔧 Files:

```
atp_simulator/
├── atp_simulator.c         // Main ATP logic (threaded request handler)
├── udp_socket.c            // Socket initialization and wrappers
├── udp_socket.h            // Header for socket functions
├── atp_protocol.h          // Shared structs and enums
└── Makefile
```

---

## 📄 `udp_socket.h`

```c
#ifndef UDP_SOCKET_H
#define UDP_SOCKET_H

#include <netinet/in.h>

int create_udp_server_socket(int port);
int udp_receive(int sockfd, void *buffer, int buffer_size, struct sockaddr_in *client_addr, socklen_t *client_len);
int udp_send(int sockfd, void *buffer, int buffer_size, struct sockaddr_in *client_addr, socklen_t client_len);

#endif
```

---

## 📄 `udp_socket.c`

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include "udp_socket.h"

int create_udp_server_socket(int port) {
    int sockfd;
    struct sockaddr_in server_addr;

    if ((sockfd = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
        perror("Socket creation failed");
        exit(EXIT_FAILURE);
    }

    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(port);

    if (bind(sockfd, (const struct sockaddr *)&server_addr, sizeof(server_addr)) < 0) {
        perror("Bind failed");
        close(sockfd);
        exit(EXIT_FAILURE);
    }

    return sockfd;
}

int udp_receive(int sockfd, void *buffer, int buffer_size, struct sockaddr_in *client_addr, socklen_t *client_len) {
    return recvfrom(sockfd, buffer, buffer_size, 0,
                    (struct sockaddr *)client_addr, client_len);
}

int udp_send(int sockfd, void *buffer, int buffer_size, struct sockaddr_in *client_addr, socklen_t client_len) {
    return sendto(sockfd, buffer, buffer_size, 0,
                  (const struct sockaddr *)client_addr, client_len);
}
```

---

## 📄 Modified `atp_simulator.c`

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <arpa/inet.h>
#include "atp_protocol.h"
#include "udp_socket.h"

#define PORT 8885
#define BUFFER_SIZE 1024

void *handle_request(void *arg) {
    int sockfd = *((int *)arg);
    free(arg);

    struct sockaddr_in client_addr;
    socklen_t client_len = sizeof(client_addr);
    char buffer[BUFFER_SIZE];

    int n = udp_receive(sockfd, buffer, BUFFER_SIZE, &client_addr, &client_len);
    if (n < sizeof(InterCompMessageSharedStruct)) {
        fprintf(stderr, "[ATP] Invalid message size: %d\n", n);
        return NULL;
    }

    InterCompMessageSharedStruct *reqHeader = (InterCompMessageSharedStruct *)buffer;
    printf("[ATP] Received message ID: %d from component %d\n",
           reqHeader->messageID, reqHeader->senderComponent);

    // Prepare response
    OCM_task_complete_Rsp rsp = {0};
    rsp.interCompMessageSharedStruct.messageID = reqHeader->messageID + 1000;
    rsp.interCompMessageSharedStruct.senderComponent = 2; // ATP ID
    rsp.interCompMessageSharedStruct.destinationComponent = reqHeader->senderComponent;
    rsp.interCompMessageSharedStruct.messageSize = sizeof(rsp);

    switch (reqHeader->messageID) {
        case INTERCOMP_MSG_ID_OCM2_INIT:
            rsp.taskType = INIT_HANDLER;
            break;
        case INTERCOMP_MSG_ID_GTP_AL_START:
            rsp.taskType = START_HANDLER;
            break;
        case INTERCOMP_MSG_ID_PDCP_TX_RESET:
            rsp.taskType = RESTART_HANDLER;
            break;
        case INTERCOMP_MSG_ID_OCM2_DESTROY:
            rsp.taskType = SHUTDOWN_HANDLER;
            break;
        default:
            rsp.taskType = CONFIGURE_DEBUG_AND_LOG_HANDLER;
    }

    udp_send(sockfd, &rsp, sizeof(rsp), &client_addr, client_len);
    printf("[ATP] Responded with taskType: %d\n", rsp.taskType);

    return NULL;
}

int main() {
    printf("[ATP] Starting ATP simulator...\n");
    int sockfd = create_udp_server_socket(PORT);

    while (1) {
        pthread_t tid;
        int *sock_arg = malloc(sizeof(int));
        *sock_arg = sockfd;

        if (pthread_create(&tid, NULL, handle_request, sock_arg) != 0) {
            perror("Thread creation failed");
            continue;
        }
        pthread_detach(tid);
    }

    close(sockfd);
    return 0;
}
```

---

## 📄 Updated `Makefile`

```make
CC = gcc
CFLAGS = -Wall -pthread

all: atp_simulator

atp_simulator: atp_simulator.c udp_socket.c
	$(CC) $(CFLAGS) -o atp_simulator atp_simulator.c udp_socket.c

clean:
	rm -f atp_simulator
```

---

## ✅ How to Run

```bash
make
./atp_simulator
```

Send a test message (e.g., INIT):

```bash
python3 -c 'import socket, struct; s=socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.sendto(struct.pack("4i", 1001, 10, 2, 16), ("127.0.0.1", 8885))'
```

---

Great — you're asking **how to take GTest logic like `WaitAndSendInitOrStartResponse()`**, which mocks ATP behavior in a test, and **repurpose it into a real ATP simulator in C**, running as a **standalone process** (not a test anymore).

---

## ✅ What That GTest Code Does

Inside `WaitAndSendInitOrStartResponse()`:

* A UDP socket listens for an INIT or START message.
* It receives a message (probably `InterCompMessageSharedStruct`).
* It sends a mock response (`OCM_task_complete_Rsp`) back to the sender.

---

## 🚀 Your Goal in C

You're replicating this behavior as an **ATP process**, in plain C, without GTest.

---

## ✅ Step-by-Step: Repurpose `WaitAndSendInitOrStartResponse()` into C ATP Simulator

---

### 🧱 Step 1: Understand the GTest Function (Simplified)

Let’s assume the C++ test looked like:

```cpp
void WaitAndSendInitOrStartResponse(uint32_t mSec) {
    // 1. Wait for INIT message
    auto msg = socket.recv();
    
    // 2. Build OCM_task_complete_Rsp with taskType = INIT_HANDLER
    OCM_task_complete_Rsp rsp;
    rsp.taskType = INIT_HANDLER;

    // 3. Send back to sender (ACP)
    socket.send(rsp);
}
```

You want to do **this logic in C**, using raw UDP sockets.

---

### ✅ Step 2: C Implementation

Below is a minimal **C version of that GTest function logic**, running as a **standalone executable**.

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>

#define INIT_PORT 8885
#define BUFFER_SIZE 1024

// Enums and structs based on your earlier images

typedef enum {
    INIT_HANDLER = 0,
    START_HANDLER,
    UPDATE_DYNAMIC_CONFIG_HANDLER,
    RESTART_HANDLER,
    SHUTDOWN_HANDLER,
    CONFIGURE_DEBUG_AND_LOG_HANDLER
} API_Names;

typedef struct {
    int messageID;
    int senderComponent;
    int destinationComponent;
    int messageSize;
} InterCompMessageSharedStruct;

typedef struct {
    InterCompMessageSharedStruct interCompMessageSharedStruct;
    API_Names taskType;
} OCM_task_complete_Rsp;

int main() {
    int sockfd;
    struct sockaddr_in atp_addr, acp_addr;
    socklen_t acp_len = sizeof(acp_addr);
    char recv_buffer[BUFFER_SIZE];

    // 1. Create UDP socket
    sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd < 0) {
        perror("socket() failed");
        exit(EXIT_FAILURE);
    }

    // 2. Bind to INIT_PORT
    memset(&atp_addr, 0, sizeof(atp_addr));
    atp_addr.sin_family = AF_INET;
    atp_addr.sin_addr.s_addr = INADDR_ANY;
    atp_addr.sin_port = htons(INIT_PORT);

    if (bind(sockfd, (struct sockaddr *)&atp_addr, sizeof(atp_addr)) < 0) {
        perror("bind() failed");
        close(sockfd);
        exit(EXIT_FAILURE);
    }

    printf("[ATP] Waiting for INIT or START message on port %d...\n", INIT_PORT);

    // 3. Wait and receive
    int n = recvfrom(sockfd, recv_buffer, BUFFER_SIZE, 0,
                     (struct sockaddr *)&acp_addr, &acp_len);
    if (n < sizeof(InterCompMessageSharedStruct)) {
        fprintf(stderr, "[ATP] Received too-small message.\n");
        close(sockfd);
        return 1;
    }

    InterCompMessageSharedStruct *incoming = (InterCompMessageSharedStruct *)recv_buffer;

    printf("[ATP] Received messageID = %d from sender = %d\n",
           incoming->messageID, incoming->senderComponent);

    // 4. Build and send response
    OCM_task_complete_Rsp rsp;
    memset(&rsp, 0, sizeof(rsp));

    rsp.interCompMessageSharedStruct.messageID = incoming->messageID + 1000; // Arbitrary
    rsp.interCompMessageSharedStruct.senderComponent = 2; // ATP component ID
    rsp.interCompMessageSharedStruct.destinationComponent = incoming->senderComponent;
    rsp.interCompMessageSharedStruct.messageSize = sizeof(rsp);

    // Select appropriate taskType based on messageID
    if (incoming->messageID == 1001) {
        rsp.taskType = INIT_HANDLER;
    } else if (incoming->messageID == 1002) {
        rsp.taskType = START_HANDLER;
    } else {
        rsp.taskType = CONFIGURE_DEBUG_AND_LOG_HANDLER;
    }

    // 5. Send response back
    sendto(sockfd, &rsp, sizeof(rsp), 0,
           (struct sockaddr *)&acp_addr, acp_len);

    printf("[ATP] Sent taskType %d as response\n", rsp.taskType);

    close(sockfd);
    return 0;
}
```

---

### ✅ Build and Run

Save as `atp_wait_response.c`:

```bash
gcc -o atp_simulator atp_wait_response.c
./atp_simulator
```

Then send a test message using Python:

```bash
# Simulate ACP sending INIT (messageID = 1001)
python3 -c 'import socket, struct; s=socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.sendto(struct.pack("4i", 1001, 10, 2, 16), ("127.0.0.1", 8885))'
```

---

## ✅ Summary

| GTest Mock         | C ATP Simulator              |
| ------------------ | ---------------------------- |
| `WaitAndSend...()` | `recvfrom()`, `sendto()`     |
| Mocked response    | Real UDP response            |
| Test thread        | Real server loop (or thread) |
| Controlled timing  | Blocking socket I/O          |

---

Would you like this wrapped into a **modular C app with multiple handlers**, or want me to show how to unit test this ATP logic?

