import socket, struct

def ip2long(ip):
  """
  Convert an IP string to long
  """
  try:
  	packedIP = socket.inet_aton(ip)
  except socket.error:
  	return -1
  return struct.unpack("!L", packedIP)[0]


def flow2IP(flowID):
    """
    Convert flowID to IP string
    """
    try:
       IP = socket.inet_ntoa(struct.pack('!L', flowID))
    except socket.error:
       return -1
    return IP
