#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ApplicationInterface

// Returns the list of attributes
// excluded from the scope of the batch object modification.
//
Function NotEditableInGroupProcessingAttributes() Export
	
	NotEditableAttributes = New Array;
	NotEditableAttributes.Add("IssuedToWhom");
	NotEditableAttributes.Add("firm");
	NotEditableAttributes.Add("Surname");
	NotEditableAttributes.Add("Name");
	NotEditableAttributes.Add("Patronymic");
	NotEditableAttributes.Add("Position");
	NotEditableAttributes.Add("WhoIssued");
	NotEditableAttributes.Add("ValidUntil");
	NotEditableAttributes.Add("Signing");
	NotEditableAttributes.Add("Encryption");
	NotEditableAttributes.Add("Imprint");
	NotEditableAttributes.Add("CertificateData");
	NotEditableAttributes.Add("Application");
	NotEditableAttributes.Add("Revoked");
	NotEditableAttributes.Add("EnhancedProtectionPrivateKey");
	NotEditableAttributes.Add("Company");
	NotEditableAttributes.Add("User");
	NotEditableAttributes.Add("AddedBy");
	NotEditableAttributes.Add("RequestStatus");
	NotEditableAttributes.Add("RequestContent");
	
	Return NotEditableAttributes;
	
EndFunction

#EndRegion

#EndIf

#Region EventsHandlers

Procedure FormGetProcessing(FormKind, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormKind = "ListForm" Then
		StandardProcessing = False;
		Parameters.Insert("ShowPageCertificates");
		SelectedForm = Metadata.CommonForms.DigitalSignaturesAndEncryptionSettings;
	EndIf;
	
EndProcedure

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	Parameters.Filter.Insert("DeletionMark", False);
	
EndProcedure

#EndRegion
