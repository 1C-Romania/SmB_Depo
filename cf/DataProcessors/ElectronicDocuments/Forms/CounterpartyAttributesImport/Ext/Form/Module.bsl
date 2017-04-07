#Region ServiceProceduresAndFunctions

&AtServer
Procedure ParseFileOnServer();
	
	XMLObject = New XMLReader;
	BinaryData = GetFromTempStorage(AddressInStorage);
	
	TempFile = ElectronicDocumentsService.TemporaryFileCurrentName("xml");
	BinaryData.Write(TempFile);
	
	Try
		XMLObject.OpenFile(TempFile);
		ED = XDTOFactory.ReadXML(XMLObject);
	Except
		XMLObject.Close();
		MessagePattern = NStr("en='Data reading from the file %1 failed: %2 (see details in Events log monitor).';ru='Возникла ошибка при чтении данных из файла %1: %2 (подробности см. в Журнале регистрации).'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern,
			TempFile, BriefErrorDescription(ErrorInfo()));
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en='ED reading';ru='Чтение ЭД.'"),
																					DetailErrorDescription(ErrorInfo()),
																					MessageText);
		Return;
	EndTry;

	XMLObject.Close();
	DeleteFiles(TempFile);
	If Not ED.Type() = ElectronicDocumentsInternal.GetCMLValueType("Counterparty") Then
		Return;
	EndIf;
	
	ValidTypes = "Country, State, Region, City, Street, House, Block, Apartment";
	
	EDProperty = ED.Properties().Get("BankAccounts");
	If EDProperty <> Undefined Then
		DataVal = ED.Get(EDProperty);
		If DataVal <> Undefined Then
			For Each CurProp IN DataVal.BankAccount Do
				BankAccount         = CurProp.AccountNo;
				BIN                   = CurProp.Bank.BIN;
				CorrespondentAccount = CurProp.Bank.AccountCorrespondent;
				Bank                  = CurProp.Bank.Description;
				
				If Not CurProp.CorrespondentBank=Undefined Then
					BankBICForSettlements                       = CurProp.CorrespondentBank.BIN;
					BankCorrAccountForSettlements                  = CurProp.CorrespondentBank.AccountCorrespondent;
					BankForSettlementsPresentation             = CurProp.CorrespondentBank.Description;
					Items.IndirectCalculationsGroup.Visible = True;
				EndIf;
			EndDo
		EndIf;
	EndIf;
	
	EDProperty = ED.Properties().Get("LegalEntity");
	If EDProperty <> Undefined Then
		
		DataVal = ED.Get(EDProperty);
		If DataVal <> Undefined Then
			TINProperty = DataVal.Properties().Get("TIN");
			If TINProperty <> Undefined Then
				TIN = DataVal.Get(TINProperty);
			EndIf;
			PropertyARBOC = DataVal.Properties().Get("OKPO");
			If PropertyARBOC <> Undefined Then
				OKPO = DataVal.Get(PropertyARBOC);
			EndIf;
			PropertyOfName = DataVal.Properties().Get("OfficialName");
			If PropertyOfName <> Undefined Then
				Description = DataVal.Get(PropertyOfName);
			EndIf;
			
			PropertyHead = DataVal.Properties().Get("Head");
			If PropertyHead <> Undefined Then
				ValHead = DataVal.Get(PropertyHead);
				If ValHead <> Undefined Then
					PropertyIndividual = ValHead.Properties().Get("Ind");
					If PropertyIndividual <> Undefined Then
						ValLegalEntityIndividial = ValHead.Get(PropertyIndividual);
						If ValLegalEntityIndividial <> Undefined Then
							HeadPost = ValLegalEntityIndividial.Position;
							Head = ValLegalEntityIndividial.FullDescr;
						EndIf;
					EndIf;
				EndIf;
			EndIf;
			
			PropertyLegAddress = DataVal.Properties().Get("LegalAddress");
			If PropertyLegAddress <> Undefined Then
				ValLegAddress = DataVal.Get(PropertyLegAddress);
				If ValLegAddress <> Undefined Then
					LegalAddress = ValLegAddress.Presentation;
					For Each CurProp IN ValLegAddress.AddressField Do
						If CurProp.Type = "Postal index" Then
							FieldsValuesLegAddress = FieldsValuesFactAddress + "IndexOf" + "=" + CurProp.Value + Chars.LF;
						ElsIf	CurProp.Type = "Settlement" Then
							FieldsValuesLegAddress = FieldsValuesFactAddress + "Settlement" + "=" + CurProp.Value + Chars.LF;
						ElsIf Find(ValidTypes, CurProp.Type)>0 THEN
							FieldsValuesLegAddress = FieldsValuesFactAddress + CurProp.Type + "=" + CurProp.Value + Chars.LF;
						EndIf;
					EndDo;
				EndIf
			EndIf;
			
		EndIf
	EndIf;
		
	EDProperty = ED.Properties().Get("Contacts");
	If EDProperty <> Undefined Then
		DataVal =  ED.Get(EDProperty);
		If DataVal <> Undefined Then
			For Each CurContact IN ED.Contacts.Contact Do
				If CurContact.Type = "Work phone" Then
					Phone = CurContact.Value;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	EDProperty = ED.Properties().Get("Address");
	If EDProperty <> Undefined Then
		DataVal = ED.Get(EDProperty);
		If DataVal <> Undefined Then
			ActualAddress = DataVal.Presentation;
			For Each CurProp IN DataVal.AddressField Do
				If CurProp.Type = "Postal index" Then
					FieldsValuesFactAddress = FieldsValuesFactAddress + "IndexOf" + "=" + CurProp.Value + Chars.LF;
				ElsIf CurProp.Type = "Settlement" Then
					FieldsValuesFactAddress = FieldsValuesFactAddress + "Settlement" + "=" + CurProp.Value + Chars.LF;
				ElsIf Find(ValidTypes, CurProp.Type)>0 THEN
					FieldsValuesFactAddress = FieldsValuesFactAddress + CurProp.Type + "=" + CurProp.Value + Chars.LF;
				EndIf;
			EndDo;
		EndIf;
	EndIf;

	TIN_KPP = "" +  TIN;

	If Not ValueIsFilled(Counterparty) Then
		DefineCounterparty();
	EndIf;
	
EndProcedure

&AtClient
Function MandatoryAttributesFilled()
	
	ClearMessages();
	AttributesFilled = True;
	If Not ValueIsFilled(Description) Then
		AttributesFilled = False;
		MessageText = NStr("en='<Name> is not filled, import is impossible.';ru='Не заполнено <Наименование>, загрузка не возможна.'");
		CommonUseClientServer.MessageToUser(MessageText);
		MessageText = NStr("en='Verify for the correctness of the <File> specification with the counterparty attribute.';ru='Проверьте правильность указания <Файла> с реквизитами контрагента.'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
	Return AttributesFilled;
	
EndFunction

&AtClient
Procedure ClearForm()
	
	Description = "";
	TIN_KPP = "";
	OKPO = "";
	HeadPost="";
	Head="";
	LegalAddress="";
	ActualAddress="";
	Phone="";
	Bank="";
	BankAccount="";
	CorrespondentAccount="";
	BIN="";
	
EndProcedure

&AtServer
Procedure FillCounterpartyAttributes()
	
	AttributesStructure = New Structure();
	AttributesStructure.Insert("Counterparty",             Counterparty);
	AttributesStructure.Insert("TIN_KPP",                TIN_KPP);
	AttributesStructure.Insert("OKPO",                   OKPO);
	AttributesStructure.Insert("Description",           Description);
	AttributesStructure.Insert("LegalAddressRepresentation",   LegalAddress);
	AttributesStructure.Insert("LegalAddressFieldValues",   FieldsValuesLegAddress);
	AttributesStructure.Insert("AddressOfRepresentation", ActualAddress);
	AttributesStructure.Insert("AddressFieldValues", FieldsValuesFactAddress);
	AttributesStructure.Insert("Phone",                Phone);
	AttributesStructure.Insert("BIN",                    BIN);
	AttributesStructure.Insert("CorrespondentAccount",  CorrespondentAccount);
	AttributesStructure.Insert("Bank",                   Bank);
	AttributesStructure.Insert("BankAccount",          BankAccount);
	
	Counterparty = ElectronicDocumentsOverridable.FillCounterpartyAttributes(AttributesStructure);
	
EndProcedure

&AtServer
Procedure DefineCounterparty()
	
	DescriptionCounterpartiesCatalog = ElectronicDocumentsReUse.GetAppliedCatalogName("Counterparties");
	If Not ValueIsFilled(DescriptionCounterpartiesCatalog) Then
		DescriptionCounterpartiesCatalog = "Counterparties";
	EndIf;

	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	Counterparties.Ref
	|FROM
	|	Catalog."+DescriptionCounterpartiesCatalog + " AS
	|Counterparties
	|	WHERE Counterparties.TIN = &TIN";
	Query.SetParameter("TIN", Mid(TIN_KPP, 1, Find(TIN_KPP, "/") - 1));
	
	Result = Query.Execute().Select();
	If Result.Next() Then
		Counterparty = Result.Ref;
	Else
		Counterparty = ElectronicDocumentsReUse.GetEmptyRef("Counterparties");
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Office handlers for asynchronous dialogs

&AtClient
Procedure FinishImport(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FillCounterpartyAttributes();
		If Not OpenFormElement Then
			ShowValue(, Counterparty);
		Else
			Notify("RefreshStateED");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure FileChoiceProcessing(Result, Address, FileName, AdditionalParameters) Export
	
	If Result = True Then
		AddressInStorage = Address;
		File = FileName;
		ParseFileOnServer();
	Else
		ClearForm();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Import(Command)
	
	If MandatoryAttributesFilled() Then
		If ValueIsFilled(Counterparty) Then
			QuestionText = NStr("en='Counterparty exists. Refill attributes?';ru='Контрагент существует. Перезаполнить реквизиты?'");
			NotifyDescription = New NotifyDescription("FinishImport", ThisObject);
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure FileBeginSelection(Item, ChoiceData, StandardProcessing)
	
	AddressInStorage = Undefined;
	Handler = New NotifyDescription("FileChoiceProcessing", ThisObject);
	BeginPutFile(Handler, AddressInStorage, , True, UUID);
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Counterparty = Parameters.Counterparty;
	
	If ValueIsFilled(Counterparty) Then
		OpenFormElement = True;
	EndIf;
	
EndProcedure

#EndRegion
