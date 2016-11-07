////////////////////////////////////////////////////////////////////////////////
// Digital signature subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Only for internal use.
Function VerifySignature(SourceDataAddress, SignatureAddress, ErrorDescription) Export
	
	Return DigitalSignature.VerifySignature(, SourceDataAddress, SignatureAddress, ErrorDescription);
	
EndFunction

// Only for internal use.
Function CheckCertificate(CertificateAddress, ErrorDescription) Export
	
	Return DigitalSignature.CheckCertificate(, CertificateAddress, ErrorDescription);
	
EndFunction

// Only for internal use.
Function ReferenceToCertificate(Imprint, CertificateAddress) Export
	
	If ValueIsFilled(CertificateAddress) Then
		BinaryData = GetFromTempStorage(CertificateAddress);
		Certificate = New CryptoCertificate(BinaryData);
		Imprint = Base64String(Certificate.Imprint);
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Imprint", Imprint);
	Query.Text =
	"SELECT
	|	Certificates.Ref AS Ref
	|FROM
	|	Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
	|WHERE
	|	Certificates.Imprint = &Imprint";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.Ref;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Only for internal use.
Function CertificatePresentation(CertificateAddress) Export
	
	CertificateData = GetFromTempStorage(CertificateAddress);
	
	CryptoCertificate = New CryptoCertificate(CertificateData);
	
	CertificateAddress = PutToTempStorage(CertificateData);
	
	Return DigitalSignatureClientServer.CertificatePresentation(CryptoCertificate, True, False);
	
EndFunction

// Only for internal use.
Function ExecuteOnServerSide(Val Parameters, ResultAddress, OperationBegan, ErrorOnServer) Export
	
	CryptoManager = DigitalSignatureService.CryptoManager(Parameters.Operation,
		False, ErrorOnServer, Parameters.CertificateApplication);
	
	If CryptoManager = Undefined Then
		Return False;
	EndIf;
	
	CryptoCertificate = DigitalSignatureService.GetCertificateByImprint(
		Parameters.CertificateThumbprint, True, False, Parameters.CertificateApplication, ErrorOnServer);
	
	If CryptoCertificate = Undefined Then
		Return False;
	EndIf;
	
	Try
		Data = GetFromTempStorage(Parameters.DataForServerItem.Data);
	Except
		ErrorInfo = ErrorInfo();
		ErrorOnServer.Insert("ErrorDescription",
			DigitalSignatureServiceClientServer.DataReceiveErrorTitle(Parameters.Operation)
			+ Chars.LF + BriefErrorDescription(ErrorInfo));
		Return False;
	EndTry;
	
	ErrorDescription = "";
	If Parameters.Operation = "Signing" Then
		CryptoManager.PrivateKeyAccessPassword = Parameters.PasswordValue;
		Try
			ResultBinaryData = CryptoManager.Sign(Data, CryptoCertificate);
			DigitalSignatureServiceClientServer.EmptySignatureData(ResultBinaryData, ErrorDescription);
		Except
			ErrorInfo = ErrorInfo();
		EndTry;
	ElsIf Parameters.Operation = "Encryption" Then
		Certificates = CryptographyCertificates(Parameters.CertificatesAddress);
		Try
			ResultBinaryData = CryptoManager.Encrypt(Data, Certificates);
			DigitalSignatureServiceClientServer.EmptyEncryptedData(ResultBinaryData, ErrorDescription);
		Except
			ErrorInfo = ErrorInfo();
		EndTry;
	Else // Details.
		CryptoManager.PrivateKeyAccessPassword = Parameters.PasswordValue;
		Try
			ResultBinaryData = CryptoManager.Decrypt(Data);
		Except
			ErrorInfo = ErrorInfo();
		EndTry;
	EndIf;
	
	If ErrorInfo <> Undefined Then
		ErrorOnServer.Insert("ErrorDescription", BriefErrorDescription(ErrorInfo));
		ErrorOnServer.Insert("Instruction", True);
		Return False;
	EndIf;
	
	If ValueIsFilled(ErrorDescription) Then
		ErrorOnServer.Insert("ErrorDescription", ErrorDescription);
		Return False;
	EndIf;
	
	OperationBegan = True;
	
	If Parameters.Operation = "Signing" Then
		CertificateProperties = DigitalSignatureClientServer.FillCertificateStructure(CryptoCertificate);
		CertificateProperties.Insert("BinaryData", CryptoCertificate.Unload());
		
		SignatureProperties = DigitalSignatureServiceClientServer.SignatureProperties(ResultBinaryData,
			CertificateProperties, Parameters.Comment);
		
		ResultAddress = PutToTempStorage(SignatureProperties, Parameters.FormID);
		
		If Parameters.DataForServerItem.Property("Object") Then
			ObjectVersioning = Undefined;
			Parameters.DataForServerItem.Property("ObjectVersioning", ObjectVersioning);
			Try
				DigitalSignature.AddSignature(Parameters.DataForServerItem.Object, SignatureProperties,
					Parameters.FormID, ObjectVersioning);
			Except
				ErrorInfo = ErrorInfo();
				ErrorOnServer.Insert("ErrorDescription", NStr("en='An error occurred writing a signature:';ru='При записи подписи возникла ошибка:'")
					+ Chars.LF + BriefErrorDescription(ErrorInfo));
				Return False;
			EndTry;
		EndIf;
	Else
		ResultAddress = PutToTempStorage(ResultBinaryData, Parameters.FormID);
	EndIf;
	
	Return True;
	
EndFunction

// Only for internal use.
Procedure AddSignature(ObjectReference, SignatureProperties, FormID, ObjectVersioning) Export
	
	DigitalSignature.AddSignature(ObjectReference, SignatureProperties, FormID, ObjectVersioning);
	
EndProcedure

// For the ExecuteOnServerSide function.
Function CryptographyCertificates(Val CertificatesProperties)
	
	If TypeOf(CertificatesProperties) = Type("String") Then
		CertificatesProperties = GetFromTempStorage(CertificatesProperties);
	EndIf;
	
	Certificates = New Array;
	For Each Properties IN CertificatesProperties Do
		Certificates.Add(New CryptoCertificate(Properties.Certificate));
	EndDo;
	
	Return Certificates;
	
EndFunction

#EndRegion
