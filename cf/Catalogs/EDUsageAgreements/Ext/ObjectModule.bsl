////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// For internal use only
Function EDFSettingUnique() Export
	
	If DeletionMark Then
		Return True;
	EndIf;
	
	If ThisObject.EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource
		AND (NOT ValueIsFilled(ThisObject.Company) OR Not ValueIsFilled(ThisObject.Counterparty)) Then
		Return True
	EndIf;
	
	CurrentSettingIsUnique = True;
	
	// Checking the unique use of setting by attributes: Company, Counterparty, CounterpartyContract.
	Query = New Query;
	Query.SetParameter("CurrentSetting",   ThisObject.Ref);
	Query.SetParameter("Company",        ThisObject.Company);
	Query.SetParameter("Counterparty",         ThisObject.Counterparty);
	Query.SetParameter("CounterpartyContract", ThisObject.CounterpartyContract);
	Query.Text =
	"SELECT ALLOWED
	|	EDFSettings.Counterparty AS Counterparty,
	|	EDFSettings.CounterpartyContract AS CounterpartyContract,
	|	EDFSettings.Company AS Company
	|FROM
	|	Catalog.EDUsageAgreements AS EDFSettings
	|WHERE
	|	Not EDFSettings.DeletionMark
	|	AND EDFSettings.Company = &Company
	|	AND EDFSettings.Counterparty = &Counterparty
	|	AND EDFSettings.CounterpartyContract = &CounterpartyContract
	|	AND EDFSettings.Ref <> &CurrentSetting";
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		CurrentSettingIsUnique = False;
		
		Selection = Result.Select();
		While Selection.Next() Do
			MessagePattern = NStr("en='In infobase EDF setting between counterparty %1 and company %2 has already existed';ru='В информационной базе уже существует настройка ЭДО между контрагентом %1 и организацией %2'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Selection.Counterparty,
				Selection.Company);
			If ValueIsFilled(Selection.CounterpartyContract) Then
				Pattern = NStr("en='%1 according to contract %2';ru='%1 по договору %2'");
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
										Pattern, MessageText, Selection.CounterpartyContract);
			EndIf;
			CommonUseClientServer.MessageToUser(MessageText);
		EndDo;
	EndIf;
	
	Return CurrentSettingIsUnique;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DeletionMark Then
		CheckedAttributes.Clear();
		Return;
	EndIf;
	
	If Not IsIntercompany
		AND (EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom
			OR EDExchangeMethod = Enums.EDExchangeMethods.ThroughEMail
			OR EDExchangeMethod = Enums.EDExchangeMethods.ThroughDirectory
			OR EDExchangeMethod = Enums.EDExchangeMethods.ThroughFTP) Then
		
		If Not ValueIsFilled(Counterparty) Then
			CommonUseClientServer.MessageToUser(
				ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Counterparty"),
				ThisObject,
				"Counterparty",
				,
				Cancel);
		EndIf;
		
		CheckDirectExchangeSettings = False;
		
		If AgreementSetupExtendedMode Then
			
			ElectronicDocumentStringArray = OutgoingDocuments.FindRows(New Structure("ToForm", True));
			For Each TableRow IN ElectronicDocumentStringArray Do
				
				Prefix = "OutgoingDocuments[" + Format(TableRow.LineNumber - 1, "NZ=0; NG=") + "].";
				
				If Not ValueIsFilled(TableRow.EDFProfileSettings) Then
					CommonUseClientServer.MessageToUser(
						ElectronicDocumentsClientServer.GetMessageText("Column", "FillType", "EDF settings profile",
						TableRow.LineNumber, "Electronic documents"),
						ThisObject,
						Prefix + "EDFProfileSettings",
						,
						Cancel);
				EndIf;
				If TableRow.EDExchangeMethod <> Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom
					AND Not ValueIsFilled(TableRow.CounterpartyID) Then
					
					CommonUseClientServer.MessageToUser(
						ElectronicDocumentsClientServer.GetMessageText("Column", "FillType", "Counterparty ID",
						TableRow.LineNumber, "Electronic documents"),
						ThisObject,
						Prefix + "CounterpartyID",
						,
						Cancel);
				EndIf;
				
				If TableRow.EDExchangeMethod = Enums.EDExchangeMethods.ThroughDirectory Then
					CheckDirectExchangeSettings = True;
					
					CheckedAttributes.Add("IncomingDocumentsDir");
					CheckedAttributes.Add("OutgoingDocumentsDir");
				ElsIf TableRow.EDExchangeMethod = Enums.EDExchangeMethods.ThroughEMail Then
					CheckDirectExchangeSettings = True;
					
					CheckedAttributes.Add("CounterpartyEmail");
				ElsIf TableRow.EDExchangeMethod = Enums.EDExchangeMethods.ThroughFTP Then
					CheckDirectExchangeSettings = True;
					
					CheckedAttributes.Add("IncomingDocumentsDirFTP");
					CheckedAttributes.Add("OutgoingDocumentsDirFTP");
				EndIf;
			EndDo;
		Else
			
			If EDExchangeMethod <> Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom
				AND Not ValueIsFilled(CounterpartyID) Then
				CommonUseClientServer.MessageToUser(
					ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Counterparty ID"),
					ThisObject,
					"CounterpartyID",
					,
					Cancel);
			EndIf;
			
			If EDExchangeMethod = Enums.EDExchangeMethods.ThroughDirectory Then
				CheckedAttributes.Add("IncomingDocumentsDir");
				CheckedAttributes.Add("OutgoingDocumentsDir");
			ElsIf EDExchangeMethod = Enums.EDExchangeMethods.ThroughEMail Then
				
				CheckedAttributes.Add("CounterpartyEmail");
			ElsIf EDExchangeMethod = Enums.EDExchangeMethods.ThroughFTP Then
				
				CheckedAttributes.Add("IncomingDocumentsDirFTP");
				CheckedAttributes.Add("OutgoingDocumentsDirFTP");
			EndIf;
		EndIf;
		
		If EDExchangeMethod = Enums.EDExchangeMethods.ThroughEMail
			OR EDExchangeMethod = Enums.EDExchangeMethods.ThroughDirectory
			OR EDExchangeMethod = Enums.EDExchangeMethods.ThroughFTP
			OR CheckDirectExchangeSettings Then
			
			ExchangeFileStringArray = ExchangeFilesFormats.FindRows(New Structure("Use, FileFormat",
				True, PredefinedValue("Enum.EDExchangeFileFormats.XML")));
			
			If ExchangeFileStringArray.Count() = 0 Then
				MessageText = NStr("en='Outgoing document format ""DocumentXML(*.xml)"" is mandatory for use.';ru='Формат исходящего документа ""ДокументХML(*.xml)"" обязателен к использованию.'");
				CommonUseClientServer.MessageToUser(MessageText, ,
					"ExchangeFilesFormats", "Object", Cancel);
			EndIf;
			
			If (ValueIsFilled(CompanyCertificateForDetails) AND Not ValueIsFilled(CounterpartyCertificateForEncryption.Get()))
				OR (NOT ValueIsFilled(CompanyCertificateForDetails) AND ValueIsFilled(CounterpartyCertificateForEncryption.Get())) Then
				
				MessageText = NStr("en='For correct encryption work
		|it is required to specify simultaneously encryption certificates for company and counterparty.';ru='Для корректной работы шифрования необходимо
		|одновременно указывать сертификаты шифрования для организации и контрагента.'");
				CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
			EndIf;
		EndIf;
		
		Return;
	EndIf;
	
	CheckedAttributes.Clear();
	If IsIntercompany AND AgreementStatus = Enums.EDAgreementsStatuses.Acts Then
		
		If Not ValueIsFilled(Company) Then
			CommonUseClientServer.MessageToUser(
				ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Company-sender"),
				ThisObject,
				"Company",
				,
				Cancel);
		EndIf;
		If Not ValueIsFilled(CompanyID) Then
			CommonUseClientServer.MessageToUser(
				ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Sender ID"),
				ThisObject,
				"CompanyID",
				,
				Cancel);
		EndIf;
		If Not ValueIsFilled(Counterparty) Then
			CommonUseClientServer.MessageToUser(
				ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Company-recipient"),
				ThisObject,
				"Counterparty",
				,
				Cancel);
		EndIf;
		If Not ValueIsFilled(CounterpartyID) Then
			CommonUseClientServer.MessageToUser(
				ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Recipient ID"),
				ThisObject,
				"CounterpartyID",
				,
				Cancel);
		EndIf;
		
		Return;
	EndIf;
	
	If EDExchangeMethod = Enums.EDExchangeMethods.ThroughBankWebSource Then
		CheckedAttributes.Clear();
		Cancel = Not ElectronicDocumentsClientServer.FilledAttributesSettingsEDFWithBanks(ThisObject);
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not EDFSettingUnique() Then
		Cancel = True;
	EndIf;
	
EndProcedure







