extends Node

# NOTE: A clanker helped me write some of this code, as I do not know enough about cryptography. Thanks, clanker!

func encrypt_string(plaintext: String, password: String) -> PackedByteArray:
	if not plaintext.strip_edges():
		return PackedByteArray()
	
	var key := _password_to_key(password)
	var iv := _generate_random_iv()
	
	var aes = AESContext.new()
	aes.start(AESContext.MODE_CBC_ENCRYPT, key, iv)
	
	var data := plaintext.to_utf8_buffer()
	var padded = _pkcs7_pad(data)
	
	var encrypted := aes.update(padded)
	aes.finish()
	
	var result = iv
	result.append_array(encrypted)
	return result

func decrypt_string(encrypted_data: PackedByteArray, password: String) -> String:
	if encrypted_data.size() < 16:
		return ""
	
	var key := _password_to_key(password)
	var iv := encrypted_data.slice(0, 16)
	var ciphertext := encrypted_data.slice(16)
	
	var aes = AESContext.new()
	aes.start(AESContext.MODE_CBC_DECRYPT, key, iv)
	
	var decrypted_padded := aes.update(ciphertext)
	aes.finish()
	
	var unpadded := _pkcs7_unpad(decrypted_padded)
	return unpadded.get_string_from_utf8()

func _password_to_key(password: String) -> PackedByteArray:
	return password.sha256_buffer()

func _generate_random_iv() -> PackedByteArray:
	var crypto = Crypto.new()
	return crypto.generate_random_bytes(16)

func _pkcs7_pad(data: PackedByteArray) -> PackedByteArray:
	var pad_len = 16 - (data.size() % 16)
	if pad_len == 16:
		pad_len = 0
	var padded = data.duplicate()
	for i in range(pad_len):
		padded.append(pad_len)
	return padded


func _pkcs7_unpad(data: PackedByteArray) -> PackedByteArray:
	if data.is_empty():
		return data
	var pad_len = data[data.size() - 1]
	if pad_len < 1 or pad_len > 16:
		return data
	return data.slice(0, data.size() - pad_len)