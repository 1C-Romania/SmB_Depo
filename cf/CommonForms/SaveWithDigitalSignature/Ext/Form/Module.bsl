&AtClient
Var ClientParameters Export;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	SaveAllSignatures = Parameters.SaveAllSignatures;
	
	If ValueIsFilled(Parameters.DataTitle) Then
		Items.DataPresentation.Title = Parameters.DataTitle;
	Else
		Items.DataPresentation.TitleLocation = FormItemTitleLocation.None;
	EndIf;
	
	DataPresentation = Parameters.DataPresentation;
	Items.DataPresentation.Hyperlink = Parameters.DataPresentationOpens;
	
	If Not ValueIsFilled(DataPresentation) Then
		Items.DataPresentation.Visible = False;
	EndIf;
	
	If Not Parameters.ShowComment Then
		Items.SignaturesTableComment.Visible = False;
	EndIf;
	
	FillSignatures(Parameters.Object);
	
	DontAskAgain = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If SaveAllSignatures Then
		Cancel = True;
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure DataPresentationClick(Item, StandardProcessing)
	
	DigitalSignatureServiceClient.DataPresentationClick(ThisObject,
		Item, StandardProcessing, ClientParameters.CurrentPresentationsList);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SelectSignature(Command)
	
	If DontAskAgain Then
		RememberNotAskAgain();
		RefreshReusableValues();
		Notify("Write_DigitalSignatureAndEncryptionPersonalSettings", New Structure, "ActionsOnSavingDS");
	EndIf;
	
	Close(SignaturesTable);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SignaturesTableSignatureAuthor.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SignaturesTableSignatureDate.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SignaturesTableComment.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("SignaturesTable.Wrong");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.SpecialTextColor);

EndProcedure

&AtServer
Procedure FillSignatures(Object)
	
	If TypeOf(Object) = Type("String") Then
		SignaturesCollection = GetFromTempStorage(Object);
	Else
		SignaturesCollection = SignaturesCollection(Object);
	EndIf;
	
	For Each AllSignatureProperties IN SignaturesCollection Do
		NewRow = SignaturesTable.Add();
		FillPropertyValues(NewRow, AllSignatureProperties);
		
		NewRow.SignatureAddress = PutToTempStorage(
			AllSignatureProperties.Signature.Get(), UUID);
		
		NewRow.Check = True;
	EndDo;
	
EndProcedure

&AtServer
Function SignaturesCollection(ObjectRef)
	
	QueryText =
	"SELECT ALLOWED
	|	DigitalSignatures.Signature AS Signature,
	|	DigitalSignatures.Signer AS Signer,
	|	DigitalSignatures.Comment AS Comment,
	|	DigitalSignatures.SignatureFileName AS SignatureFileName,
	|	DigitalSignatures.SignatureDate AS SignatureDate,
	|	DigitalSignatures.CertificateIsIssuedTo AS CertificateIsIssuedTo
	|FROM
	|	&DigitalSignatures AS DigitalSignatures
	|WHERE
	|	DigitalSignatures.Ref = &ObjectReference";
	
	Query = New Query;
	Query.Parameters.Insert("ObjectReference", ObjectRef);
	
	Query.Text = StrReplace(QueryText, "&DigitalSignatures",
		ObjectRef.Metadata().FullName() + ".DigitalSignatures");
		
	Return Query.Execute().Unload();
	
EndFunction

&AtServerNoContext
Procedure RememberNotAskAgain()
	
	SettingsPart = New Structure("ActionsOnSavingDS", "SaveAllSignatures");
	DigitalSignatureService.SavePersonalSettings(SettingsPart);
	RefreshReusableValues();
	
EndProcedure

#EndRegion














