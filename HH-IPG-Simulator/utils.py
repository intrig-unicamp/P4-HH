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