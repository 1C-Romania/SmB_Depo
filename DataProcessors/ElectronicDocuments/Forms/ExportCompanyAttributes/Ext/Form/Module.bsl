////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
Procedure ExportCompanyAttributes(StorageAddress, UUID)
	
	ErrorText = "";
	
	Try
		
		XDTOCounterparty = ElectronicDocumentsInternal.GetCMLObjectType("Counterparty", "4.02");
		ElectronicDocumentsInternal.FillXDTOProperty(XDTOCounterparty, "ID", TIN + "_" + KPP, True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(XDTOCounterparty, "Description", Description, True, ErrorText);
		
		If Not ElectronicDocumentsOverridable.ThisIsInd(Company) Then
			LegalEntityIndividualXDTO = ElectronicDocumentsInternal.GetCMLObjectType("DetailsOfLegalEntity", "4.02");
			ElectronicDocumentsInternal.FillXDTOProperty(
				LegalEntityIndividualXDTO, "OfficialName", DescriptionFull, True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(LegalEntityIndividualXDTO, "KPP", KPP, , ErrorText);
			
			If ValueIsFilled(Head) Then
				XDTOHead = ElectronicDocumentsInternal.GetCMLObjectType("Counterparty", "4.02");
				ElectronicDocumentsInternal.FillXDTOProperty(XDTOHead, "ID", Head, True, ErrorText);
				NatpersonHeadXDTO = ElectronicDocumentsInternal.GetCMLObjectType("Counterparty.Ind", "4.02");
				ElectronicDocumentsInternal.FillXDTOProperty(
					NatpersonHeadXDTO, "FullDescr", Head, True, ErrorText);
				ElectronicDocumentsInternal.FillXDTOProperty(
					NatpersonHeadXDTO, "Position", HeadPost, True, ErrorText);
				ElectronicDocumentsInternal.FillXDTOProperty(
					XDTOHead, "Ind", NatpersonHeadXDTO, True, ErrorText);
				ElectronicDocumentsInternal.FillXDTOProperty(
					LegalEntityIndividualXDTO, "Head", XDTOHead, True, ErrorText);
			EndIf;
			
			If ValueIsFilled(LegalAddress) Then
				AddressXDTO = ElectronicDocumentsInternal.GetCMLObjectType("Address", "4.02");
				ElectronicDocumentsInternal.FillXDTOProperty(AddressXDTO, "Presentation", LegalAddress, True, ErrorText);
				If ValueIsFilled(FieldsValuesLegAddress) Then
					AnalyzeAddress(AddressXDTO, FieldsValuesLegAddress, ErrorText);
				EndIf;
				ElectronicDocumentsInternal.FillXDTOProperty(LegalEntityIndividualXDTO, "LegalAddress", AddressXDTO, True, ErrorText);
			EndIf;
			
			PropertyName = "LegalEntity";
		Else
			LegalEntityIndividualXDTO = ElectronicDocumentsInternal.GetCMLObjectType("IndividualAttributes", "4.02");
			ElectronicDocumentsInternal.FillXDTOProperty(LegalEntityIndividualXDTO, "FullDescr", DescriptionFull, True, ErrorText);
			
			If ValueIsFilled(LegalAddress) Then
				AddressXDTO = ElectronicDocumentsInternal.GetCMLObjectType("Address", "4.02");
				ElectronicDocumentsInternal.FillXDTOProperty(AddressXDTO, "Presentation", LegalAddress, True, ErrorText);
				If ValueIsFilled(FieldsValuesLegAddress) Then
					AnalyzeAddress(AddressXDTO, FieldsValuesLegAddress, ErrorText);
				EndIf;
				ElectronicDocumentsInternal.FillXDTOProperty(LegalEntityIndividualXDTO, "RegistrationAddress", AddressXDTO, True, ErrorText);
			EndIf;
			
			If ValueIsFilled(CertificateDate) AND ValueIsFilled(CertificateNumber) Then
				XDTOCertificate = ElectronicDocumentsInternal.GetCMLObjectType("IndividualAttributes.Certificate", "4.02");
				ElectronicDocumentsInternal.FillXDTOProperty(
					XDTOCertificate, "Number", CertificateNumber, True, ErrorText);
				ElectronicDocumentsInternal.FillXDTOProperty(
					XDTOCertificate, "IssueDate", CertificateDate, True, ErrorText);
				ElectronicDocumentsInternal.FillXDTOProperty(
					LegalEntityIndividualXDTO, "Certificate", XDTOCertificate, True, ErrorText);
			EndIf;
			PropertyName = "Ind";
		EndIf;
		
		ElectronicDocumentsInternal.FillXDTOProperty(LegalEntityIndividualXDTO, "TIN", TIN, True, ErrorText);
		ElectronicDocumentsInternal.FillXDTOProperty(LegalEntityIndividualXDTO, "OKPO", OKPO, , ErrorText);
		
		If ValueIsFilled(ActualAddress) Then
			AddressXDTO = ElectronicDocumentsInternal.GetCMLObjectType("Address", "4.02");
			ElectronicDocumentsInternal.FillXDTOProperty(AddressXDTO, "Presentation", ActualAddress, True, ErrorText);
			If ValueIsFilled(FieldsValuesFactAddress) Then
				AnalyzeAddress(AddressXDTO, FieldsValuesFactAddress, ErrorText);
			EndIf;
			ElectronicDocumentsInternal.FillXDTOProperty(XDTOCounterparty, "Address", AddressXDTO, True, ErrorText);
		EndIf;
		
		ElectronicDocumentsInternal.FillXDTOProperty(XDTOCounterparty, PropertyName, LegalEntityIndividualXDTO, True, ErrorText);
		
		VTBankAccount = BankAccounts.Unload(New Structure("Selected", True));
		BankAttributes = ElectronicDocumentsOverridable.GetBankAttributes(
			VTBankAccount.UnloadColumn("BankAccount"));
		
		If BankAttributes.Count() > 0 Then
			
			XDTOBankAccounts = ElectronicDocumentsInternal.GetCMLObjectType("Counterparty.CurrentAccounts", "4.02");
			
			For Each Account in BankAttributes Do
				XDTOBankAccount = ElectronicDocumentsInternal.GetCMLObjectType("BankAccount", "4.02");
				ElectronicDocumentsInternal.FillXDTOProperty(
					XDTOBankAccount, "AccountNo", Account.BankAccount, True, ErrorText);
				BankXDTO = ElectronicDocumentsInternal.GetCMLObjectType("Bank", "4.02");
				ElectronicDocumentsInternal.FillXDTOProperty(BankXDTO, "BIN", Account.BIN, True, ErrorText);
				ElectronicDocumentsInternal.FillXDTOProperty(
					BankXDTO, "AccountCorrespondent", Account.CorrespondentAccount, True, ErrorText);
				ElectronicDocumentsInternal.FillXDTOProperty(BankXDTO, "Description", Account.Bank, True, ErrorText);
				ElectronicDocumentsInternal.FillXDTOProperty(XDTOBankAccount, "Bank",BankXDTO, True, ErrorText);
				
				If ValueIsFilled(Account.SettlementBank) Then
					BankXDTO = ElectronicDocumentsInternal.GetCMLObjectType("Bank", "4.02");
					ElectronicDocumentsInternal.FillXDTOProperty(BankXDTO, "BIN", Account.AccountingBankBIC, True, ErrorText);
					ElectronicDocumentsInternal.FillXDTOProperty(
						BankXDTO, "AccountCorrespondent", Account.SettlementsCorrespondentAccountBank, True, ErrorText);
					ElectronicDocumentsInternal.FillXDTOProperty(
						BankXDTO, "Description", Account.SettlementBank, True, ErrorText);
					ElectronicDocumentsInternal.FillXDTOProperty(
						XDTOBankAccount, "CorrespondentBank", BankXDTO, True, ErrorText);
				EndIf;
					
				XDTOBankAccounts.BankAccount.Add(XDTOBankAccount);
			EndDo;
			
			ElectronicDocumentsInternal.FillXDTOProperty(
				XDTOCounterparty, "BankAccounts", XDTOBankAccounts, True, ErrorText);
			
		EndIf;
		
		If ValueIsFilled(Phone) Then
			ContactInformationXDTO = ElectronicDocumentsInternal.GetCMLObjectType("ContactInformation", "4.02");
			ElectronicDocumentsInternal.FillXDTOProperty(
				ContactInformationXDTO, "Type", "Work phone", True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(ContactInformationXDTO, "Value", Phone, True, ErrorText);
			
			XDTOContacts = ElectronicDocumentsInternal.GetCMLObjectType("Counterparty.Contacts", "4.02");
			XDTOContacts.Contact.Add(ContactInformationXDTO);
			ElectronicDocumentsInternal.FillXDTOProperty(XDTOCounterparty, "Contacts", XDTOContacts, True, ErrorText);
		EndIf;
		
		XDTOCounterparty.Validate();
		
		If ErrorText = "" Then
			FileName = ElectronicDocumentsService.TemporaryFileCurrentName("xml");
			NewXMLWriter = New XMLWriter;
			NewXMLWriter.OpenFile(FileName, "UTF-8");
			NewXMLWriter.WriteXMLDeclaration();
			XDTOFactory.WriteXML(NewXMLWriter, XDTOCounterparty, , , , XMLTypeAssignment.Explicit);
			NewXMLWriter.Close();
			BinaryData = New BinaryData(FileName);
			DeleteFiles(FileName);
			
			StorageAddress = PutToTempStorage(BinaryData, UUID);
		Else
			MessagePattern = NStr("en = '%1 (see details in event log monitor).'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, ErrorText);
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en = 'ED formation'"),
																						ErrorText,
																						ErrorText);
		EndIf;
		
	Except
		
		MessagePattern = NStr("en = '%1 (see details in event log monitor).'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern,
			BriefErrorDescription(ErrorInfo()));
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(NStr("en = 'ED formation'"),
																					DetailErrorDescription(ErrorInfo()),
																					MessageText);
	EndTry;
	
EndProcedure

&AtServer
Procedure AnalyzeAddress(XDTODataObject, Value, ErrorText)

	Value = StrReplace(Value, "IndexOf",         "Postal index");
	Value = StrReplace(Value, "Settlement","Settlement");
	ValidTypes = "Postal zip code, Country, Region, Area, Settlement, City, Street, House, Building, Apartment";
	
	For IndexOf=1 To StrLineCount(Value) Do
		CurRow = StrGetLine(Value, IndexOf);
		Type = Mid(CurRow, 1, Find(CurRow, "=") - 1);
		If Find(ValidTypes, Type) > 0 Then
			AddressField = ElectronicDocumentsInternal.GetCMLObjectType("Address.AddressField", "4.02");
			ElectronicDocumentsInternal.FillXDTOProperty(AddressField, "Type", Type, True, ErrorText);
			ElectronicDocumentsInternal.FillXDTOProperty(AddressField, "Value", Mid(CurRow,Find(CurRow, "=") + 1), True, ErrorText);
			XDTODataObject.AddressField.Add(AddressField);
		EndIf;
	EndDo
	
EndProcedure

&AtServer
Function GetAccount()
	
	Query = New Query();
	Query.Text =
	"SELECT ALLOWED
	|	EmailAccounts.Ref
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	EmailAccounts.DeletionMark = FALSE
	|	AND EmailAccounts.UseForSending = TRUE";
		
	Result = Query.Execute().Select();
	If Result.Count() = 1 Then
		Result.Next();
		Return Result.Ref;
	EndIf;
	
	Return Catalogs.EmailAccounts.EmptyRef();

EndFunction

&AtServer
Function GetDetails()
	
	ReturnStructure = New Structure();
	ReturnStructure.Insert("Description");
	ReturnStructure.Insert("DescriptionFull");
	ReturnStructure.Insert("TIN");
	ReturnStructure.Insert("KPP");
	ReturnStructure.Insert("OKPO");
	ReturnStructure.Insert("HeadPost");
	ReturnStructure.Insert("Head");
	ReturnStructure.Insert("LegalEntityIndividual");
	ReturnStructure.Insert("CertificateDate");
	ReturnStructure.Insert("CertificateNumber");
	ReturnStructure.Insert("LegalAddress");
	ReturnStructure.Insert("FieldsValuesLegAddress");
	ReturnStructure.Insert("ActualAddress");
	ReturnStructure.Insert("FieldsValuesFactAddress");
	ReturnStructure.Insert("Phone");
	
	Return ReturnStructure;

EndFunction

&AtClient
Procedure RefreshForm()
	
	If ExportMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEMail") Then
		Items.PayeePages.CurrentPage = Items.PageLetter;
	ElsIf ExportMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughDirectory") Then
		Items.PayeePages.CurrentPage = Items.PageDirectory;
	EndIf;
	If LegalEntityIndividual = AnIndividualEntrepreneur Then
		Items.GroupHead.Visible = False;
		Items.KPP.Visible                = False;
		
		LabelCertificate = NStr("en ='Certificate No'") + CertificateNumber + NStr("en =' from '") + Format(CertificateDate, "DLF=D");
	Else
		Items.Certificate.Visible = False;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - Form commands actions

&AtClient
Procedure ExportAttributes(Command)
	
	ClearMessages();
	
	If Not CheckFilling() THEN
		Return;
	EndIf;
	
	If ExportMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEMail") Then
		If Not ValueIsFilled(ExportingAddress) Then
			MessageText = NStr("en = 'Email account is not specified.'");
			CommonUseClientServer.MessageToUser(MessageText);
			Return;
		EndIf;
	EndIf;
	
	StorageAddress = Undefined;
	ExportCompanyAttributes(StorageAddress, UUID);
	If StorageAddress = Undefined Then
		Return;
	EndIf;
	
	If ExportMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughDirectory") Then
		
		DefaultFileName = Description;
		DefaultFileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(DefaultFileName, "");
		
		GetFile(StorageAddress, DefaultFileName + "xml");

	ElsIf ExportMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEMail") Then
		DataFileName = Description + ".xml";
		DataFileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(DataFileName, "");
	
		FormParameters = New Structure;
		FormParameters.Insert("Subject", "Attributes " + Description);
		FormParameters.Insert("UserAccount", ExportingAddress);
		FileName = DataFileName;
		While True Do
			Pos = Max(Find(FileName, "\"), Find(FileName, "/"));
			If Pos = 0 Then
				Break;
			EndIf;
			FileName = Mid(FileName, Pos + 1);
		EndDo;
		Attachments = New ValueList;
		NewItem = Attachments.Add(StorageAddress, FileName);
		FormParameters.Insert("Attachments", Attachments);
		Form = OpenForm("CommonForm.MessageSending", FormParameters);
	EndIf;
	
	Close();

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM FIELD EVENT HANDLERS

&AtClient
Procedure ExportMethodOnChange(Item)
	
	ExportingAddress = "";
	If ExportMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEMail") Then
		ExportingAddress = GetAccount();
	EndIf;
	RefreshForm();
	Modified = False;
	
EndProcedure

&AtClient
Procedure UserAccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	ExportingAddress = PredefinedValue("Catalog.EmailAccounts.EmptyRef");
	
EndProcedure

&AtClient
Procedure BankAccountsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "BankAccount" Then
		ShowValue(, Item.CurrentData.BankAccount);
	EndIf
	
EndProcedure

&AtClient
Procedure BankAccountsSelectedOnChange(Item)
	
	If Items.BankAccounts.CurrentData.Selected Then
		LineNumber = 0;
		CurrentNumber = Items.BankAccounts.CurrentRow + 1;
		For Each String IN BankAccounts Do
			LineNumber = LineNumber + 1;
			If LineNumber <> CurrentNumber Then
				String.Selected = False;
			EndIf;
		EndDo
	EndIf
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Company     = Parameters.Company;
	DataStructure = GetDetails();
	ElectronicDocumentsOverridable.GetCompanyAttributesForExportToFile(Company, DataStructure);
	FillPropertyValues(ThisObject, DataStructure);
	
	TablBankAccounts = ElectronicDocumentsOverridable.GetBankAccounts(Company);
	BankAccounts.Load(TablBankAccounts);
	
	If ExportMethod = Enums.EDExchangeMethods.ThroughEMail Then
		ExportingAddress = GetAccount();
	EndIf;
	
	AnIndividualEntrepreneur = ElectronicDocumentsReUse.FindEnumeration("LegalEntityIndividual", "AnIndividualEntrepreneur");

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ValueIsFilled(ExportMethod) Then
		ExportMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughDirectory");
	EndIf;
	
	If ExportMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughEMail")
		AND Not ValueIsFilled(ExportingAddress) Then
		ExportingAddress = GetAccount();
	EndIf;
		
	RefreshForm();
	
EndProcedure
