/** 
 @file  enet.h
 @brief ENet public header file
*/
#ifndef __ENET_ENET_H__
#define __ENET_ENET_H__

#ifdef __cplusplus
extern "C"
{
#endif

#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include "enet/win32.h"
#else
#include "enet/unix.h"
#endif

#include "enet/types.h"
#include "enet/protocol.h"
#include "enet/list.h"
#include "enet/callbacks.h"

typedef enum
{
   ENET_VERSION = 1
} ENetVersion;

typedef enum
{
   ENET_SOCKET_TYPE_STREAM   = 1,
   ENET_SOCKET_TYPE_DATAGRAM = 2
} ENetSocketType;

typedef enum
{
   ENET_SOCKET_WAIT_NONE    = 0,
   ENET_SOCKET_WAIT_SEND    = (1 << 0),
   ENET_SOCKET_WAIT_RECEIVE = (1 << 1)
} ENetSocketWait;

enum
{
   ENET_HOST_ANY       = 0,            /**< specifies the default server host */
   ENET_HOST_BROADCAST = 0xFFFFFFFF    /**< specifies a subnet-wide broadcast */
};

/**
 * Portable internet address structure. 
 *
 * The host must be specified in network byte-order, and the port must be in host 
 * byte-order. The constant ENET_HOST_ANY may be used to specify the default 
 * server host. The constant ENET_HOST_BROADCAST may be used to specify the
 * broadcast address (255.255.255.255).  This makes sense for enet_host_connect,
 * but not for enet_host_create.  Once a server responds to a broadcast, the
 * address is updated from ENET_HOST_BROADCAST to the server's actual IP address.
 */
typedef struct _ENetAddress
{
   enet_uint32 host;
   enet_uint16 port;
} ENetAddress;

/**
 * Packet flag bit constants.
 *
 * The host must be specified in network byte-order, and the port must be in
 * host byte-order. The constant ENET_HOST_ANY may be used to specify the
 * default server host.
 
   @sa ENetPacket
*/
typedef enum
{
   /** packet must be received by the target peer and resend attempts should be
     * made until the packet is delivered */
   ENET_PACKET_FLAG_RELIABLE    = (1 << 0),
   /** packet will not be sequenced with other packets
     * not supported for reliable packets
     */
   ENET_PACKET_FLAG_UNSEQUENCED = (1 << 1)
} ENetPacketFlag;

/**
 * ENet packet structure.
 *
 * An ENet data packet that may be sent to or received from a peer. The shown 
 * fields should only be read and never modified. The data field contains the 
 * allocated data for the packet. The dataLength fields specifies the length 
 * of the allocated data.  The flags field is either 0 (specifying no flags), 
 * or a bitwise-or of any combination of the following flags:
 *
 *    ENET_PACKET_FLAG_RELIABLE - packet must be received by the target peer
 *    and resend attempts should be made until the packet is delivered
 
   @sa ENetPacketFlag
 */
typedef struct _ENetPacket
{
   size_t               referenceCount;  /**< internal use only */
   enet_uint32          flags;           /**< bitwise or of ENetPacketFlag constants */
   enet_uint8 *         data;            /**< allocated data for packet */
   size_t               dataLength;      /**< length of data */
} ENetPacket;

typedef struct _ENetAcknowledgement
{
   ENetListNode acknowledgementList;
   enet_uint32  sentTime;
   ENetProtocol command;
} ENetAcknowledgement;

typedef struct _ENetOutgoingCommand
{
   ENetListNode outgoingCommandList;
   enet_uint32  reliableSequenceNumber;
   enet_uint32  unreliableSequenceNumber;
   enet_uint32  sentTime;
   enet_uint32  roundTripTimeout;
   enet_uint32  roundTripTimeoutLimit;
   enet_uint32  fragmentOffset;
   enet_uint16  fragmentLength;
   ENetProtocol command;
   ENetPacket * packet;
} ENetOutgoingCommand;

typedef struct _ENetIncomingCommand
{  
   ENetListNode     incomingCommandList;
   enet_uint32      reliableSequenceNumber;
   enet_uint32      unreliableSequenceNumber;
   ENetProtocol     command;
   enet_uint32      fragmentCount;
   enet_uint32      fragmentsRemaining;
   enet_uint32 *    fragments;
   ENetPacket *     packet;
} ENetIncomingCommand;

typedef enum
{
   ENET_PEER_STATE_DISCONNECTED                = 0,
   ENET_PEER_STATE_CONNECTING                  = 1,
   ENET_PEER_STATE_ACKNOWLEDGING_CONNECT       = 2,
   ENET_PEER_STATE_CONNECTED                   = 3,
   ENET_PEER_STATE_DISCONNECTING               = 4,
   ENET_PEER_STATE_ACKNOWLEDGING_DISCONNECT    = 5,
   ENET_PEER_STATE_ZOMBIE                      = 6
} ENetPeerState;

#ifndef ENET_BUFFER_MAXIMUM
#define ENET_BUFFER_MAXIMUM (1 + 2 * ENET_PROTOCOL_MAXIMUM_PACKET_COMMANDS)
#endif

enum
{
   ENET_HOST_RECEIVE_BUFFER_SIZE          = 256 * 1024,
   ENET_HOST_BANDWIDTH_THROTTLE_INTERVAL  = 1000,
   ENET_HOST_DEFAULT_MTU                  = 1400,

   ENET_PEER_DEFAULT_ROUND_TRIP_TIME      = 500,
   ENET_PEER_DEFAULT_PACKET_THROTTLE      = 32,
   ENET_PEER_PACKET_THROTTLE_SCALE        = 32,
   ENET_PEER_PACKET_THROTTLE_COUNTER      = 7, 
   ENET_PEER_PACKET_THROTTLE_ACCELERATION = 2,
   ENET_PEER_PACKET_THROTTLE_DECELERATION = 2,
   ENET_PEER_PACKET_THROTTLE_INTERVAL     = 5000,
   ENET_PEER_PACKET_LOSS_SCALE            = (1 << 16),
   ENET_PEER_PACKET_LOSS_INTERVAL         = 10000,
   ENET_PEER_WINDOW_SIZE_SCALE            = 64 * 1024,
   ENET_PEER_TIMEOUT_LIMIT                = 32,
   ENET_PEER_TIMEOUT_MINIMUM              = 3000,
   ENET_PEER_TIMEOUT_MAXIMUM              = 30000,
   ENET_PEER_PING_INTERVAL                = 500,
   ENET_PEER_UNSEQUENCED_WINDOW_SIZE      = 4 * 32,
};

typedef struct _ENetChannel
{
   enet_uint32  outgoingReliableSequenceNumber;
   enet_uint32  outgoingUnreliableSequenceNumber;
   enet_uint32  incomingReliableSequenceNumber;
   enet_uint32  incomingUnreliableSequenceNumber;
   ENetList     incomingReliableCommands;
   ENetList     incomingUnreliableCommands;
} ENetChannel;

/**
 * An ENet peer which data packets may be sent or received from. 
 *
 * No fields should be modified unless otherwise specified. 
 */
typedef struct _ENetPeer
{ 
   struct _ENetHost * host;
   enet_uint16   outgoingPeerID;
   enet_uint16   incomingPeerID;
   enet_uint32   challenge;
   ENetAddress   address;            /**< Internet address of the peer */
   void *        data;               /**< Application private data, may be freely modified */
   ENetPeerState state;
   ENetChannel * channels;
   size_t        channelCount;       /**< Number of channels allocated for communication with peer */
   enet_uint32   incomingBandwidth;  /**< Downstream bandwidth of the client in bytes/second */
   enet_uint32   outgoingBandwidth;  /**< Upstream bandwidth of the client in bytes/second */
   enet_uint32   incomingBandwidthThrottleEpoch;
   enet_uint32   outgoingBandwidthThrottleEpoch;
   enet_uint32   incomingDataTotal;
   enet_uint32   outgoingDataTotal;
   enet_uint32   lastSendTime;
   enet_uint32   lastReceiveTime;
   enet_uint32   nextTimeout;
   enet_uint32   earliestTimeout;
   enet_uint32   packetLossEpoch;
   enet_uint32   packetsSent;
   enet_uint32   packetsLost;
   enet_uint32   packetLoss;          /**< mean packet loss of reliable packets as a ratio with respect to the constant ENET_PEER_PACKET_LOSS_SCALE */
   enet_uint32   packetLossVariance;
   enet_uint32   packetThrottle;
   enet_uint32   packetThrottleLimit;
   enet_uint32   packetThrottleCounter;
   enet_uint32   packetThrottleEpoch;
   enet_uint32   packetThrottleAcceleration;
   enet_uint32   packetThrottleDeceleration;
   enet_uint32   packetThrottleInterval;
   enet_uint32   lastRoundTripTime;
   enet_uint32   lowestRoundTripTime;
   enet_uint32   lastRoundTripTimeVariance;
   enet_uint32   highestRoundTripTimeVariance;
   enet_uint32   roundTripTime;            /**< mean round trip time (RTT), in milliseconds, between sending a reliable packet and receiving its acknowledgement */
   enet_uint32   roundTripTimeVariance;
   enet_uint16   mtu;
   enet_uint32   windowSize;
   enet_uint32   reliableDataInTransit;
   enet_uint32   outgoingReliableSequenceNumber;
   ENetList      acknowledgements;
   ENetList      sentReliableCommands;
   ENetList      sentUnreliableCommands;
   ENetList      outgoingReliableCommands;
   ENetList      outgoingUnreliableCommands;
   enet_uint32   incomingUnsequencedGroup;
   enet_uint32   outgoingUnsequencedGroup;
   enet_uint32   unsequencedWindow [ENET_PEER_UNSEQUENCED_WINDOW_SIZE / 32]; 
} ENetPeer;

/** An ENet host for communicating with peers.
  *
  * No fields should be modified.

    @sa enet_host_create()
    @sa enet_host_destroy()
    @sa enet_host_connect()
    @sa enet_host_service()
    @sa enet_host_flush()
    @sa enet_host_broadcast()
    @sa enet_host_bandwidth_limit()
    @sa enet_host_bandwidth_throttle()
  */
typedef struct _ENetHost
{
   ENetSocket         socket;
   ENetAddress        address;                     /**< Internet address of the host */
   enet_uint32        incomingBandwidth;           /**< downstream bandwidth of the host */
   enet_uint32        outgoingBandwidth;           /**< upstream bandwidth of the host */
   enet_uint32        bandwidthThrottleEpoch;
   enet_uint32        mtu;
   int                recalculateBandwidthLimits;
   ENetPeer *         peers;                       /**< array of peers allocated for this host */
   size_t             peerCount;                   /**< number of peers allocated for this host */
   ENetPeer *         lastServicedPeer;
   size_t             packetSize;
   ENetProtocol       commands [ENET_PROTOCOL_MAXIMUM_PACKET_COMMANDS];
   size_t             commandCount;
   ENetBuffer         buffers [ENET_BUFFER_MAXIMUM];
   size_t             bufferCount;
   ENetAddress        receivedAddress;
   enet_uint8         receivedData [ENET_PROTOCOL_MAXIMUM_MTU];
   size_t             receivedDataLength;
} ENetHost;

/**
 * An ENet event type, as specified in @ref ENetEvent.
 */
typedef enum
{
   /** no event occurred within the specified time limit */
   ENET_EVENT_TYPE_NONE       = 0,  

   /** a connection request initiated by enet_host_connect has completed.  
     * The peer field contains the peer which successfully connected. 
     */
   ENET_EVENT_TYPE_CONNECT    = 1,  

   /** a peer has disconnected.  This event is generated on a successful 
     * completion of a disconnect initiated by enet_pper_disconnect, if 
     * a peer has timed out, or if a connection request intialized by 
     * enet_host_connect has timed out.  The peer field contains the peer 
     * which disconnected. 
     */
   ENET_EVENT_TYPE_DISCONNECT = 2,  

   /** a packet has been received from a peer.  The peer field specifies the
     * peer which sent the packet.  The channelID field specifies the channel
     * number upon which the packet was received.  The packet field contains
     * the packet that was received; this packet must be destroyed with
     * enet_packet_destroy after use.
     */
   ENET_EVENT_TYPE_RECEIVE    = 3
} ENetEventType;

/**
 * An ENet event as returned by enet_host_service().
   
   @sa enet_host_service
 */
typedef struct _ENetEvent 
{
   ENetEventType        type;      /**< type of the event */
   ENetPeer *           peer;      /**< peer that generated a connect, disconnect or receive event */
   enet_uint8           channelID;
   ENetPacket *         packet;
} ENetEvent;

/** @defgroup global ENet global functions
    @{ 
*/

/** 
  Initializes ENet globally.  Must be called prior to using any functions in
  ENet.
  @returns 0 on success, < 0 on failure
*/
ENET_API int enet_initialize (void);

ENET_API int enet_initialize_with_callbacks (ENetVersion version, const ENetCallbacks * inits);

/** 
  Shuts down ENet globally.  Should be called when a program that has
  initialized ENet exits.
*/
ENET_API void enet_deinitialize (void);

/** @} */

/** @defgroup private ENet private implementation functions */

/**
  Returns the wall-time in milliseconds.  Its initial value is unspecified
  unless otherwise set.
  */
ENET_API enet_uint32 enet_time_get (void);
/**
  Sets the current wall-time in milliseconds.
  */
ENET_API void enet_time_set (enet_uint32);

/** @defgroup socket ENet socket functions
    @{
    @ingroup private
*/
extern ENetSocket enet_socket_create (ENetSocketType, const ENetAddress *);
extern ENetSocket enet_socket_accept (ENetSocket, ENetAddress *);
extern int        enet_socket_connect (ENetSocket, const ENetAddress *);
extern int        enet_socket_send (ENetSocket, const ENetAddress *, const ENetBuffer *, size_t);
extern int        enet_socket_receive (ENetSocket, ENetAddress *, ENetBuffer *, size_t);
extern int        enet_socket_wait (ENetSocket, enet_uint32 *, enet_uint32);
extern void       enet_socket_destroy (ENetSocket);

/** @} */

/** @defgroup Address ENet address functions
    @{
*/
/** Attempts to resolve the host named by the parameter hostName and sets
    the host field in the address parameter if successful.
    @param address destination to store resolved address
    @param hostName host name to lookup
    @retval 0 on success
    @retval < 0 on failure
    @returns the address of the given hostName in address on success
*/
ENET_API int enet_address_set_host (ENetAddress *address, const char *hostName );

/** Attempts to do a reserve lookup of the host field in the address parameter.
    @param address    address used for reverse lookup
    @param hostName   destination for name, must not be NULL
    @param nameLength maximum length of hostName.
    @returns the null-terminated name of the host in hostName on success
    @retval 0 on success
    @retval < 0 on failure
*/
ENET_API int enet_address_get_host (const ENetAddress *address, char *hostName, size_t nameLength );

/** @} */

ENET_API ENetPacket * enet_packet_create (const void *dataContents, size_t dataLength, enet_uint32 flags);
ENET_API void         enet_packet_destroy (ENetPacket *packet );
ENET_API int          enet_packet_resize  (ENetPacket *packet, size_t dataLength );

ENET_API ENetHost * enet_host_create (const ENetAddress *address, size_t peerCount, enet_uint32 incomingBandwidth, enet_uint32 outgoingBandwidth );
ENET_API void       enet_host_destroy (ENetHost *host );
ENET_API ENetPeer * enet_host_connect (ENetHost *host, const ENetAddress *address, size_t channelCount );
ENET_API int        enet_host_service (ENetHost *, ENetEvent *, enet_uint32);
ENET_API void       enet_host_flush (ENetHost *);
ENET_API void       enet_host_broadcast (ENetHost *, enet_uint8, ENetPacket *);
ENET_API void       enet_host_bandwidth_limit (ENetHost *, enet_uint32, enet_uint32);
extern   void       enet_host_bandwidth_throttle (ENetHost *);

ENET_API int                 enet_peer_send (ENetPeer *, enet_uint8, ENetPacket *);
ENET_API ENetPacket *        enet_peer_receive (ENetPeer *, enet_uint8);
ENET_API void                enet_peer_ping (ENetPeer *);
ENET_API void                enet_peer_reset (ENetPeer *);
ENET_API void                enet_peer_disconnect (ENetPeer *);
ENET_API void                enet_peer_disconnect_now (ENetPeer *);
ENET_API void                enet_peer_throttle_configure (ENetPeer *, enet_uint32, enet_uint32, enet_uint32);
extern int                   enet_peer_throttle (ENetPeer *, enet_uint32);
extern void                  enet_peer_reset_queues (ENetPeer *);
extern ENetOutgoingCommand * enet_peer_queue_outgoing_command (ENetPeer *, const ENetProtocol *, ENetPacket *, enet_uint32, enet_uint16);
extern ENetIncomingCommand * enet_peer_queue_incoming_command (ENetPeer *, const ENetProtocol *, ENetPacket *, enet_uint32);
extern ENetAcknowledgement * enet_peer_queue_acknowledgement (ENetPeer *, const ENetProtocol *, enet_uint32);

#ifdef __cplusplus
}
#endif

#endif /* __ENET_ENET_H__ */

