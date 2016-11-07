// Form is parameterized:
//
//      Title     - String  - form title.
//      FieldsValues - String  - serialized value of the contact details or
//  empty string to enter a new one.
//      Presentation - String  - address presentation (used only when working with old data).
//      ContactInformationKind - CatalogRef.ContactInformationTypes, Structure - description
//                                of what we are editing.
//      Comment  - String   - optional comment for substitution in the "Comment" field.
//
//      ReturnValueList - Boolean - optional flag showing that the return value of a field.
//                                 ContactInformation will have ValueList type (compatibility).
//
//  Selection result:
//      Structure - fields:
//          * ContactInformation   - String - Contact information XML.
//          * Presentation          - String - Presentation.
//          * Comment            - String - Comment.
//
// -------------------------------------------------------------------------------------------------

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("ReturnValueList", ReturnValueList);
	
	// Parsing parameters into attributes.
	If TypeOf(Parameters.ContactInformationKind) = Type("CatalogRef.ContactInformationTypes") Then 
		ContactInformationKind = Parameters.ContactInformationKind;
		ContactInformationType = ContactInformationKind.Type;
	Else
		ContactInformationStructureKind = Parameters.ContactInformationKind;
		ContactInformationType = ContactInformationStructureKind.Type;
	EndIf;
	
	CheckCorrectness      = ContactInformationKind.CheckCorrectness;
	ProhibitEntryOfIncorrect = ContactInformationKind.ProhibitEntryOfIncorrect;
	
	Title = ?(IsBlankString(Parameters.Title), String(ContactInformationKind), Parameters.Title);
	
	If ContactInformationManagementClientServer.IsContactInformationInXML(Parameters.FieldsValues) Then
		ReadingResults = New Structure;
		XDTOContact = ContactInformationManagementService.ContactInformationFromXML(Parameters.FieldsValues, ContactInformationType, ReadingResults);
		If ReadingResults.Property("ErrorText") Then
			// Recognized with errors, will notify on opening.
			WarningTextOnOpen = ReadingResults.ErrorText;
			XDTOContact.Presentation   = Parameters.Presentation;
		EndIf;
		
	ElsIf ContactInformationType = Enums.ContactInformationTypes.Phone Then
		XDTOContact = ContactInformationManagementService.DeserializationPhone(Parameters.FieldsValues, Parameters.Presentation, ContactInformationType);
		
	Else
		XDTOContact = ContactInformationManagementService.DeserializingFax(Parameters.FieldsValues, Parameters.Presentation, ContactInformationType);
		
	EndIf;
	
	If Parameters.Comment <> Undefined Then
		ContactInformationManagement.SetContactInformationComment(XDTOContact, Parameters.Comment);
	EndIf;
	
	ValueofAttributesByContactInformation(XDTOContact);
	
	// Command group "all activity" depends on the interface.
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi Then
		Items.FormAllActions.Visible = False;
	Else
		Items.ClearPhone.Visible = False;
		Items.ChangeForm.Visible   = False;
	EndIf;
		
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetCommentIcon();

	If Not IsBlankString(WarningTextOnOpen) Then
		AttachIdleHandler("Attachable_AlertAfterOpeningForms", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	Notification = New NotifyDescription("ConfirmAndClose", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure CountryCodeOnChange(Item)
	
	FillPhonePresentation();
	
EndProcedure

&AtClient
Procedure CityCodeOnChange(Item)
	
	If (CountryCode = "+7" OR CountryCode = "8") AND Left(CityCode, 1) = "9" AND StrLen(CityCode) <> 3 Then
		CommonUseClientServer.MessageToUser(NStr("en='Codes of the mobile phones starting with the digit 9 have the fixed length of 3 digits, for example 916.';ru='Кода мобильных телефонов начинающиеся на цифру 9 имеют фиксированную длину в 3 цифры, например - 916.'"),, "CityCode");
	EndIf;
	
	FillPhonePresentation();
EndProcedure

&AtClient
Procedure PhoneNumberOnChange(Item)
	
	FillPhonePresentation();
	
EndProcedure

&AtClient
Procedure AdditionalOnChange(Item)
	
	FillPhonePresentation();
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("SetCommentIcon", 0.1, True);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandOK(Command)
	ConfirmAndClose();
EndProcedure

&AtClient
Procedure CommandCancel(Command)
	
	Modified = False;
	Close();
	
EndProcedure

&AtClient
Procedure ClearPhone(Command)
	
	ClearPhoneServer();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure Attachable_WarnAfterFormOpening()
	
	CommonUseClientServer.MessageToUser(WarningTextOnOpen);
	
EndProcedure

&AtClient
Procedure SetCommentIcon()
	
	If IsBlankString(Comment) Then
		Items.PhonePageComment.Picture = New Picture;
	Else
		Items.PhonePageComment.Picture = PictureLib.Comment;
	EndIf;
		
EndProcedure

&AtClient
Procedure ConfirmAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	// "Cancel" works when it is not modified.
	
	If Modified Then
		// Address value is changed 
		
		AreFillingErrors = False;
		// Look whether it is necessary to check for correctness.
		If CheckCorrectness Then
			ErrorList = FillPhoneErrorsServer();
			AreFillingErrors = ErrorList.Count()>0;
		EndIf;
		If AreFillingErrors Then
			FillErrorMessage(ErrorList);
			If ProhibitEntryOfIncorrect Then
				Return;
			EndIf;
		EndIf;
		Result = ChoiceResult();
		
		DropModifiedOnChoice();
		NotifyChoice(Result);
		
	ElsIf Comment<>CopyComment Then
		// Only comment is changed, try to return the updated.
		Result = ChoiceResultOnlyComment();
		
		DropModifiedOnChoice();
		NotifyChoice(Result);
		
	Else
		Result = Undefined;
		
	EndIf;
	
	If (ModalMode Or CloseOnChoice) AND IsOpen() Then
		DropModifiedOnChoice();
		Close(Result);
	EndIf;
	
EndProcedure

&AtClient
Procedure DropModifiedOnChoice()
	
	Modified = False;
	CopyComment   = Comment;
	
EndProcedure

&AtServer
Function ChoiceResult()
	XDTOInformation = ContactInformationForAttributesValue();
	
	If ReturnValueList Then
		ChoiceData = ContactInformationManagementService.ContactInformationInOldStructure(XDTOInformation);
		ChoiceData = ChoiceData.FieldsValues;
	Else
		ChoiceData = ContactInformationManagementService.ContactInformationXDTOVXML(XDTOInformation);
	EndIf;
		
	Return New Structure("ContactInformation, Presentation, Comment",
		ChoiceData,
		XDTOInformation.Presentation, 
		XDTOInformation.Comment);
EndFunction

&AtServer
Function ChoiceResultOnlyComment()
	
	ContactInfo = Parameters.FieldsValues;
	If IsBlankString(ContactInfo) Then
		If ContactInformationType = Enums.ContactInformationTypes.Phone Then
			ContactInfo = ContactInformationManagementService.DeserializationPhone("", "", ContactInformationType);
		Else
			ContactInfo = ContactInformationManagementService.DeserializingFax("", "", ContactInformationType);
		EndIf;
		ContactInformationManagement.SetContactInformationComment(ContactInfo, Comment);
		ContactInfo = ContactInformationManagement.XMLContactInformation(ContactInfo);
		
	ElsIf ContactInformationManagementClientServer.IsContactInformationInXML(ContactInfo) Then
		ContactInformationManagement.SetContactInformationComment(ContactInfo, Comment);
	EndIf;
	
	Return New Structure("ContactInformation, Presentation, Comment",
		ContactInfo, Parameters.Presentation, Comment);
EndFunction

// Fills attributes of the form from the XTDO object of the "Contact information" type.
&AtServer
Procedure ValueofAttributesByContactInformation(EditableInformation)
	
	Phone = EditableInformation.Content;
	
	// Common attributes
	Presentation = EditableInformation.Presentation;
	Comment   = EditableInformation.Comment;
	
	// Copy of the comment for the changes analysis.
	CopyComment = Comment;
	
	CountryCode     = Phone.CountryCode;
	CityCode     = Phone.CityCode;
	PhoneNumber = Phone.Number;
	Supplementary    = Phone.Supplementary;
	
EndProcedure

// Returns XTDO object of the "Contact information" type by the attributes value.
&AtServer
Function ContactInformationForAttributesValue()
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	
	Result = XDTOFactory.Create( XDTOFactory.Type(TargetNamespace, "ContactInformation") );
	
	If ContactInformationType = Enums.ContactInformationTypes.Phone Then
		Data = XDTOFactory.Create( XDTOFactory.Type(TargetNamespace, "PhoneNumber") );
		Data.CountryCode  = CountryCode;
		Data.CityCode  = CityCode;
		Data.Number      = PhoneNumber;
		Data.Supplementary = Supplementary;
		Result.Presentation = ContactInformationManagementService.PresentationPhone(Data);
	Else        
		Data = XDTOFactory.Create( XDTOFactory.Type(TargetNamespace, "FaxNumber") );
		Data.CountryCode  = CountryCode;
		Data.CityCode  = CityCode;
		Data.Number      = PhoneNumber;
		Data.Supplementary = Supplementary;
		Result.Presentation = ContactInformationManagementService.FaxPresentation(Data);
	EndIf;
	
	Result.Content      = Data;
	Result.Comment = Comment;
	
	Return Result;
EndFunction

&AtClient
Procedure FillPhonePresentation()
	
	AttachIdleHandler("FillPhonePresentationNow", 0.1, True);
	
EndProcedure    

&AtClient
Procedure FillPhonePresentationNow()
	
	FillPhonePresentationServer();
	
EndProcedure    

&AtServer
Procedure FillPhonePresentationServer(XDTOContact = Undefined)
	
	Info = ?(XDTOContact = Undefined, ContactInformationForAttributesValue(), XDTOContact);
	Presentation = Info.Presentation;
	
EndProcedure    

// Returns a list of filling errors in the form of values list:
//      Presentation   - error description.
//      Value        - XPath for field.
&AtServer
Function FillPhoneErrorsServer() 
	Return New ValueList();
EndFunction    

// Reports about filling errors according to the results of the FillPhoneErrorsServer function.
&AtClient
Procedure FillErrorMessage(ErrorList)
	
	If ErrorList.Count()=0 Then
		ShowMessageBox(, NStr("en='Phone number is entered correctly.';ru='Телефон введен корректно.'"));
		Return;
	EndIf;
	
	ClearMessages();
	
	// Value - XPath, presentation - error description.
	For Each Item In ErrorList Do
		CommonUseClientServer.MessageToUser(Item.Presentation,,,
		PathToFormDataByPathXPath(Item.Value));
	EndDo;
	
EndProcedure    

&AtClient 
Function PathToFormDataByPathXPath(PathXPath) 
	Return PathXPath;
EndFunction

&AtServer
Procedure ClearPhoneServer()
	CountryCode     = "";
	CityCode     = "";
	PhoneNumber = "";
	Supplementary    = "";
	Comment   = "";
	
	FillPhonePresentationServer();
	Modified = True;
EndProcedure


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
