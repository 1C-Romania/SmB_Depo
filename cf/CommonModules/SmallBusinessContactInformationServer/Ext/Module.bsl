////////////////////////////////////////////////////////////////////////////////
// SB SERVICE PROCEDURES AND FUNCTIONS

//The function returns description of metadata types for which it is required to extract email addresses
//
Function GetTypesOfMetadataContainingAffiliateEmail() Export
	
	ListOfMetadataTypesContainingEmails = New ValueList;
	
	ListOfMetadataTypesContainingEmails.Add(New TypeDescription("CatalogRef.Counterparties"));
	ListOfMetadataTypesContainingEmails.Add(New TypeDescription("CatalogRef.ContactPersons"));
	
	Return ListOfMetadataTypesContainingEmails;
	
EndFunction // GetTypesOfMetadataContainingAffiliateEmail()

// The function generates recipients with email addresses to send an email.
//
// Parameters:
//  Recipients			 - Values list	 - valid types of items CatalogRef.Counterparties, CatalogRef.ContactPersons
//  WithSubordinate - Boolean	 - shows that contact persons for counterparties are included in the result 
// Return value:
//  Array - Array of structures , string keys:
//   * Presentation - CatalogRef.Counterparties, CatalogRef.ContactPersons
//   * Address - String
//   * Name - not used
Function PrepareRecipientsEmailAddresses(val Recipients, Recursive = True) Export
	
	RecipientsEmailAddresses = New Array;
	If Recipients.Count() = 0 Then
		Return RecipientsEmailAddresses;
	EndIf;
	EmailAddress = Enums.ContactInformationTypes.EmailAddress;
	
	ArrayOfRecipients = Recipients.UnloadValues();
	TableEmail = ContactInformationManagement.ObjectsContactInformation(ArrayOfRecipients, EmailAddress);
	
	For Each Recipient in Recipients Do
		
		ValueListElementValue = Recipient.Value;
		
		AddressesEP = "";
		FoundStringArray = TableEmail.FindRows(New Structure("Object", ValueListElementValue));
		For Each CIRow IN FoundStringArray Do
			AddressesEP = AddressesEP + ?(AddressesEP = "", "", ", ") + CIRow.Presentation;
		EndDo;
		
		StructureRecipient = New Structure("
			|Presentation,
			|Address,
			|PostalAddressKind"); // Is necessary for reading an SSL subsystem - CommonForm.NewEmailPreparation
		StructureRecipient.Presentation = ValueListElementValue;
		StructureRecipient.Address = AddressesEP;
		
		RecipientsEmailAddresses.Add(StructureRecipient);
		
		// Receive Email contact persons with help of recursion
		If Recursive 
			AND TypeOf(ValueListElementValue) = Type("CatalogRef.Counterparties") Then
			
			ContactPersonsEmailAddresses = PrepareRecipientsEmailAddresses(
				SmallBusinessServer.GetCounterpartyContactPersons(ValueListElementValue),
				False);
			
			For Each ItemOfAddress IN ContactPersonsEmailAddresses Do
				
				RecipientsEmailAddresses.Add(ItemOfAddress);
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	Return RecipientsEmailAddresses;
	
EndFunction

// The function returns field value "FieldsValues" of contact information
//
// Ref - ref to catalog (Organization, Counterparty)
//  ContactInformationKind - contact information kind (Catalog.ContactInformationKinds)
//
Function GetValueOfContactInformationFields(Ref, ContactInformationKind) Export
	
	If Not ValueIsFilled(Ref) 
		OR Not ValueIsFilled(ContactInformationKind) Then
		
		Return "";
		
	EndIf;
	
	ContactInformation = Ref.ContactInformation.Find(ContactInformationKind, "Kind");
	If ContactInformation = Undefined Then
		
		Return "";
		
	EndIf;
	
	Return ContactInformation.FieldsValues;
	
EndFunction // GetValueOfContactInformationFields()

// Determines that the email recipient is multiway
//
Function MoreThenOneRecipient(Recipient) Export
	
	If TypeOf(Recipient) = Type("Array") Or TypeOf(Recipient) = Type("ValueList") Then
		
		Return Recipient.Count() > 1;
		
	Else
		
		Return CommonUseClientServer.EmailsFromString(Recipient).Count() > 1;
		
	EndIf;
	
EndFunction // MoreThenOneRecipient()
