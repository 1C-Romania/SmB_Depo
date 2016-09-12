
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If ValueIsFilled(Parameters.CertificateAddress) Then
		CertificateData = GetFromTempStorage(Parameters.CertificateAddress);
		Certificate = New CryptoCertificate(CertificateData);
		CertificateAddress = PutToTempStorage(CertificateData, UUID);
		
	ElsIf ValueIsFilled(Parameters.Ref) Then
		CertificateAddress = CertificateAddress(Parameters.Ref, UUID);
		
		If CertificateAddress = Undefined Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Unable to open the"
"%1 certificate as it is not found in the catalog.';ru='Не удалось открыть сертификат ""%1"","
"т.к. он не найден в справочнике.'"), Parameters.Ref);
		EndIf;
	Else // Imprint
		CertificateAddress = CertificateAddress(Parameters.Imprint, UUID);
		
		If CertificateAddress = Undefined Then
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Unable to open certificate as it was"
"not found using the %1 thumbprint.';ru='Не удалось открыть сертификат, т.к. он не найден"
"по отпечатку ""%1"".'"), Parameters.Imprint);
		EndIf;
	EndIf;
	
	If CertificateData = Undefined Then
		CertificateData = GetFromTempStorage(CertificateAddress);
		Certificate = New CryptoCertificate(CertificateData);
	EndIf;
	
	CertificateStructure = DigitalSignatureClientServer.FillCertificateStructure(Certificate);
	
	PurposeSigning = Certificate.UseToSign;
	PurposeEncryption = Certificate.UseForEncryption;
	
	Imprint      = CertificateStructure.Imprint;
	IssuedToWhom      = CertificateStructure.IssuedToWhom;
	WhoIssued       = CertificateStructure.WhoIssued;
	ValidUntil = CertificateStructure.ValidUntil;
	
	FillCertificatePurposeCodes(CertificateStructure.Purpose, PurposeCodes);
	
	FillSubjectProperties(Certificate);
	FillIssuerProperties(Certificate);
	
	InternalFieldsGroup = "Common";
	FillCertificateInternalFields();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure InternalFieldsGroupAfterChange(Item)
	
	FillCertificateInternalFields();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SaveToFile(Command)
	
	DigitalSignatureServiceClient.SaveCertificate(, CertificateAddress);
	
EndProcedure

&AtClient
Procedure Validate(Command)
	
	DigitalSignatureClient.CheckCertificate(New NotifyDescription(
		"CheckEnd", ThisObject), CertificateAddress);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Continue the Check procedure.
&AtClient
Procedure CheckEnd(Result, NotSpecified) Export
	
	If Result = True Then
		ShowMessageBox(, NStr("en='The certificate is valid.';ru='Сертификат действителен.'"));
		
	ElsIf Result <> Undefined Then
		ShowMessageBox(, NStr("en='Certificate is invalid due to:';ru='Сертификат недействителен по причине:'")
			+ Chars.LF + Result);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillSubjectProperties(Certificate)
	
	Collection = DigitalSignatureClientServer.CertificateSubjectProperties(Certificate);
	
	PropertiesPresentation = New ValueList;
	PropertiesPresentation.Add("CommonName",         NStr("en='Common name';ru='Общее имя'"));
	PropertiesPresentation.Add("Country",           NStr("en='Country';ru='Страна'"));
	PropertiesPresentation.Add("Region",           NStr("en='Region';ru='Регион'"));
	PropertiesPresentation.Add("Settlement",  NStr("en='Settlement';ru='НаселПункт'"));
	PropertiesPresentation.Add("Street",            NStr("en='Street';ru='Улица'"));
	PropertiesPresentation.Add("Company",      NStr("en = 'Company'"));
	PropertiesPresentation.Add("Division",    NStr("en='Division';ru='разделение'"));
	PropertiesPresentation.Add("Position",        NStr("en='Position';ru='Position'"));
	PropertiesPresentation.Add("Email", NStr("en='Email';ru='Электронное письмо'"));
	PropertiesPresentation.Add("OGRN",             NStr("en='OGRN';ru='ОГРН'"));
	PropertiesPresentation.Add("OGRNIP",           NStr("en='OGRNIP';ru='ОГРНИП'"));
	PropertiesPresentation.Add("INILA",            NStr("en='INILA';ru='СНИЛС'"));
	PropertiesPresentation.Add("TIN",              NStr("en='TIN';ru='ИНН'"));
	PropertiesPresentation.Add("Surname",          NStr("en='Surname';ru='Фамилия'"));
	PropertiesPresentation.Add("Name",              NStr("en='Name';ru='Имя'"));
	PropertiesPresentation.Add("Patronymic",         NStr("en='Patronymic';ru='Отчество'"));
	
	For Each ItemOfList IN PropertiesPresentation Do
		If Not ValueIsFilled(Collection[ItemOfList.Value]) Then
			Continue;
		EndIf;
		String = Subject.Add();
		String.Property = ItemOfList.Presentation;
		String.Value = Collection[ItemOfList.Value];
	EndDo;
	
EndProcedure

&AtServer
Procedure FillIssuerProperties(Certificate)
	
	Collection = DigitalSignatureClientServer.CertificateIssuerProperties(Certificate);
	
	PropertiesPresentation = New ValueList;
	PropertiesPresentation.Add("CommonName",         NStr("en='Common name';ru='Общее имя'"));
	PropertiesPresentation.Add("Country",           NStr("en='Country';ru='Страна'"));
	PropertiesPresentation.Add("Region",           NStr("en='Region';ru='Регион'"));
	PropertiesPresentation.Add("Settlement",  NStr("en='Settlement';ru='НаселПункт'"));
	PropertiesPresentation.Add("Street",            NStr("en='Street';ru='Улица'"));
	PropertiesPresentation.Add("Company",      NStr("en = 'Company'"));
	PropertiesPresentation.Add("Division",    NStr("en='Division';ru='разделение'"));
	PropertiesPresentation.Add("Email", NStr("en='Email';ru='Электронное письмо'"));
	PropertiesPresentation.Add("OGRN",             NStr("en='OGRN';ru='ОГРН'"));
	PropertiesPresentation.Add("TIN",              NStr("en='TIN';ru='ИНН'"));
	
	For Each ItemOfList IN PropertiesPresentation Do
		If Not ValueIsFilled(Collection[ItemOfList.Value]) Then
			Continue;
		EndIf;
		String = Issuer.Add();
		String.Property = ItemOfList.Presentation;
		String.Value = Collection[ItemOfList.Value];
	EndDo;
	
EndProcedure

&AtServer
Procedure FillCertificateInternalFields()
	
	InnerContent.Clear();
	CertificateBinaryData = GetFromTempStorage(CertificateAddress);
	Certificate = New CryptoCertificate(CertificateBinaryData);
	
	If InternalFieldsGroup = "Common" Then
		AddProperty(Certificate, "Version",                    NStr("en='Version';ru='Версия'"));
		AddProperty(Certificate, "StartDate",                NStr("en='Start date';ru='Дата начала'"));
		AddProperty(Certificate, "EndDate",             NStr("en='End date';ru='Дата окончания'"));
		AddProperty(Certificate, "UseToSign",    NStr("en='Use to sign';ru='Использовать для подписи'"));
		AddProperty(Certificate, "UseForEncryption", NStr("en='Use for encryption';ru='Использовать для шифрования'"));
		AddProperty(Certificate, "OpenKey",              NStr("en='Open key';ru='Открытый ключ'"), True);
		AddProperty(Certificate, "Imprint",                 NStr("en='Imprint';ru='Отпечаток'"), True);
		AddProperty(Certificate, "SerialNumber",             NStr("en='Serial number';ru='Серийный номер'"), True);
	Else
		Collection = Certificate[InternalFieldsGroup];
		For Each KeyAndValue IN Collection Do
			AddProperty(Collection, KeyAndValue.Key, KeyAndValue.Key);
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure AddProperty(PropertyValues, Property, Presentation, LowerRegister = Undefined)
	
	Value = PropertyValues[Property];
	If TypeOf(Value) = Type("Date") Then
		Value = ToLocalTime(Value, SessionTimeZone());
	ElsIf TypeOf(Value) = Type("FixedArray") Then
		FixedArray = Value;
		Value = "";
		For Each ArrayElement IN FixedArray Do
			Value = Value + ?(Value = "", "", Chars.LF) + TrimAll(ArrayElement);
		EndDo;
	EndIf;
	
	String = InnerContent.Add();
	String.Property = Presentation;
	
	If LowerRegister = True Then
		String.Value = Lower(Value);
	Else
		String.Value = Value;
	EndIf;
	
EndProcedure

// Converts certificates destinations to destination codes.
//  
// Parameters:
//  Purpose    - String - multiline certificate purpose, for example:
//                           Microsoft Encrypted File System (1.3.6.1.4.1.311.10.3.4)
//                           |Email Protection (1.3.6.1.5.5.7.3.4)
//                           |TLS Web Client Authentication (1.3.6.1.5.5.7.3.2).
//  
//  PurposeCodes - String - Destination codes 1.3.6.1.4.1.311.10.3.4, 1.3.6.1.5.5.7.3.4, 1.3.6.1.5.5.7.3.2.
//
&AtServer
Procedure FillCertificatePurposeCodes(Purpose, PurposeCodes)
	
	SetPrivilegedMode(True);
	
	Codes = "";
	
	For IndexOf = 1 To StrLineCount(Purpose) Do
		
		String = StrGetLine(Purpose, IndexOf);
		CurrentCode = "";
		
		Position = StringFunctionsClientServer.FindCharFromEnd(String, "(");
		If Position <> 0 Then
			CurrentCode = Mid(String, Position + 1, StrLen(String) - Position - 1);
		EndIf;
		
		If ValueIsFilled(CurrentCode) Then
			Codes = Codes + ?(Codes = "", "", ", ") + TrimAll(CurrentCode);
		EndIf;
		
	EndDo;
	
	PurposeCodes = Codes;
	
EndProcedure

&AtServer
Function CertificateAddress(RefsThumbprint, FormID = Undefined)
	
	CertificateData = Undefined;
	
	If TypeOf(RefsThumbprint) = Type("CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates") Then
		Storage = CommonUse.ObjectAttributeValue(RefsThumbprint, "CertificateData");
		If TypeOf(Storage) = Type("ValueStorage") Then
			CertificateData = Storage.Get();
		EndIf;
	Else
		Query = New Query;
		Query.SetParameter("Imprint", RefsThumbprint);
		Query.Text =
		"SELECT
		|	Certificates.CertificateData
		|FROM
		|	Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
		|WHERE
		|	Certificates.Imprint = &Imprint";
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			CertificateData = Selection.CertificateData.Get();
		Else
			Certificate = DigitalSignatureService.GetCertificateByImprint(RefsThumbprint, False, False);
			If Certificate <> Undefined Then
				CertificateData = Certificate.Unload();
			EndIf;
		EndIf;
	EndIf;
	
	If TypeOf(CertificateData) = Type("BinaryData") Then
		Return PutToTempStorage(CertificateData, FormID);
	EndIf;
	
	Return Undefined;
	
EndFunction

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
