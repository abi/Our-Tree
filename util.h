
/* Prints a character array as hexadecimal string. Useful for printing ciphertext. */
void printh (char *buffer)
{
	for (int i=0; buffer[i] != '\0'; i++)
		printf ("%02x", buffer[i]);
	printf ("\n");
}
