
#Region Interface

// If XMLString is not defined, than ExpectingKind - mandatory
//
Procedure SetContactInformationComment(XMLString, Comment, ExpectedKind = Undefined) Export
	
	If IsBlankString(XMLString) Then
		XMLString = ContactInformationManagement.ContactInformationXMLByPresentation("", ExpectedKind);
	EndIf;
	
	ContactInformationManagement.SetContactInformationComment(XMLString, Comment);
	
КонецПроцедуры

// Function wrapper for the call from the client.
// Description see ContactInformationManagement.ContactInformationXMLByPresentation()
Function ContactInformationXMLByPresentation(Presentation, ExpectedKind) Export
	
	Return ContactInformationManagement.ContactInformationXMLByPresentation(Presentation, ExpectedKind);
	
EndFunction

#EndRegion