
// Procedure adds attachments-pictures from a formatted document for emailing.
//
// Parameters:
//  HTMLText		 - String		 - HTML source text of email. Parameter is being changed in the procedure.
//  EmailAttachments	 - Map	 - see comment to  WorkWithPostalMessagesService.SendMessage (). Parameter is being changed in the procedure.
//  AttachmentsImages - Structure	 - see syntax-assistant FormattedDocument.GetHTML() the Attachments parameter
Procedure AddAttachmentsImagesInEmail(HTMLText, EmailAttachments, val AttachmentsImages) Export
	
	MatchImageNameToIdentifier = New Map;
	
	For Each KeyAndValue IN AttachmentsImages Do
		
		PictureID = New UUID;
		MatchImageNameToIdentifier.Insert(KeyAndValue.Key, PictureID);
		
		AttachmentDescription = New Structure("BinaryData, Identifier");
		AttachmentDescription.BinaryData = KeyAndValue.Value.GetBinaryData();
		AttachmentDescription.ID = PictureID;
		EmailAttachments.Insert(KeyAndValue.Key, AttachmentDescription);
		
	EndDo;
	
	HTMLDocument = GetObjectDocumentHTMLFromHTMLText(HTMLText);
	
	For Each Picture IN HTMLDocument.Images Do
		
		AttributePictureSource = Picture.Attributes.GetNamedItem("src");
		
		PictureNewAttribute = AttributePictureSource.CloneNode(False);
		PictureNewAttribute.TextContent = "cid:" + MatchImageNameToIdentifier.Get(AttributePictureSource.TextContent);
		Picture.Attributes.SetNamedItem(PictureNewAttribute);
		
	EndDo;
	
	HTMLText = GetHTMLTextFromObjectHTMLDocument(HTMLDocument);
	
EndProcedure

// Function receives an object - HTML document from HTML text
//
// Parameters:
//  HTMLText	 - String	 - HTML
//  text Encoding	 - String	 - Specifies the encoding that will be used in the HTML parsing mechanism for conversion.
// Returns:
//  HTMLDocument - object
Function GetObjectDocumentHTMLFromHTMLText(HTMLText, Encoding = Undefined) Export
	
	Builder = New DOMBuilder;
	HTMLReader = New HTMLReader;
	
	NewHTMLText = HTMLText;
	PositionOpeningXML = Find(NewHTMLText,"<?xml");
	
	If PositionOpeningXML > 0 Then
		
		PositionClosingXML = Find(NewHTMLText,"?>");
		If PositionClosingXML > 0 Then
			NewHTMLText = Left(NewHTMLText, PositionOpeningXML - 1) + Right(NewHTMLText, StrLen(NewHTMLText) - PositionClosingXML -1);
		EndIf;
		
	EndIf;
	
	If Encoding = Undefined Then
		HTMLReader.SetString(HTMLText);
	Else
		HTMLReader.SetString(HTMLText, Encoding);
	EndIf;
	
	Return Builder.Read(HTMLReader);
	
EndFunction

// Function receives HTML text from the HTMLDocument object
//
// Parameters:
//  HTMLDocument	 - HTMLDocument	 - document from which the
// Return value text will be extracted:
//  String - HTML text
Function GetHTMLTextFromObjectHTMLDocument(HTMLDocument) Export
	
	DOMWriter = New DOMWriter;
	HTMLWriter = New HTMLWriter;
	HTMLWriter.SetString();
	DOMWriter.Write(HTMLDocument,HTMLWriter);
	
	Return HTMLWriter.Close();
	
EndFunction

// Function receives HTML text from the HTMLDocument object
//
// Parameters:
//  HTMLDocument	 - HTMLDocument	 - document from which the
// Return value text will be extracted:
//  String - HTML text
Function GetTextFromHTML(HTMLText) Export
	
	FD = New FormattedDocument;
	FD.SetHTML(HTMLText, New Structure);
	
	Return FD.GetText();
	
EndFunction

// Function matches the SMS delivery status received from the provider to the corresponding enumeration
//
// Parameters:
//  DeliveryStatusInRow	 - String	 - status received
// from the Return value provider:
//  EnumRef.SMSMessageStates - matching result
Function MapSMSDeliveryStatus(DeliveryStatusInRow) Export
	
	StatusesCorrespondence = New Map;
	StatusesCorrespondence.Insert("",				Enums.SMSMessageStates.Outgoing);
	StatusesCorrespondence.Insert("HaveNotSent", Enums.SMSMessageStates.Outgoing);
	StatusesCorrespondence.Insert("Dispatched",	Enums.SMSMessageStates.IsSentByProvider);
	StatusesCorrespondence.Insert("Sent",		Enums.SMSMessageStates.SentByProvider);
	StatusesCorrespondence.Insert("NotSent",	Enums.SMSMessageStates.NotSentByProvider);
	StatusesCorrespondence.Insert("Delivered",		Enums.SMSMessageStates.Delivered);
	StatusesCorrespondence.Insert("NotDelivered",	Enums.SMSMessageStates.NotDelivered);
	
	Result = StatusesCorrespondence[DeliveryStatusInRow];
	Return ?(Result = Undefined, Enums.SMSMessageStates.ErrorObtainingStatusOfInternetServiceProvider, Result);
	
EndFunction
