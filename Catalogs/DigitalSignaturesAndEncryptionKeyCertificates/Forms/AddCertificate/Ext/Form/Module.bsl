
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	CommonSettings = DigitalSignatureClientServer.CommonSettings();
	
	If CommonSettings.CertificateIssueApplicationAvailable
	   AND Not Parameters.HideApplication Then
		
		MethodAddCertificate = "RequestForCertificateIssue";
		If Not CommonSettings.UseEncryption Then
			Items.Pages.CurrentPage = Items.PageMethodAddCertificateWithoutEncryption;
		EndIf;
	Else
		Items.PageMethodAddCertificate.Visible = False;
		Items.PageMethodAddCertificateWithoutEncryption.Visible = False;
	EndIf;
	
	Purpose = "ForSigningEncryptionAndDecryption";
	If Not ValueIsFilled(MethodAddCertificate) Then
		Items.Pages.CurrentPage = Items.PurposePage;
	EndIf;
	
	If Not CommonSettings.UseDigitalSignatures Then
		Purpose = "ForEncryptionAndDecryption";
		If Not ValueIsFilled(MethodAddCertificate) Then
			Items.Pages.CurrentPage = Items.PagePurposeWithoutDigitalSignature;
		EndIf;
		
	ElsIf Not CommonSettings.UseEncryption
	        AND Not ValueIsFilled(MethodAddCertificate) Then
		Cancel = True;
		Return;
	EndIf;
	
	SetCommandsContentForEncryptionOnly(ThisObject);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure MethodAddCertificateOnChange(Item)
	
	SetCommandsContentOnChangingCertificateAddMethod();
	
EndProcedure

&AtClient
Procedure PurposeOnChange(Item)
	
	SetCommandsContentForEncryptionOnly(ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Add(Command)
	
	If Items.Pages.CurrentPage = Items.PageMethodAddCertificate
	 Or Items.Pages.CurrentPage = Items.PageMethodAddCertificateWithoutEncryption Then
		
		Close(MethodAddCertificate);
	Else
		Close(Purpose);
	EndIf;
	
EndProcedure

&AtClient
Procedure Next(Command)
	
	If DigitalSignatureClientServer.CommonSettings().UseDigitalSignatures Then
		Items.Pages.CurrentPage = Items.PurposePage;
		Purpose = "ForSigningEncryptionAndDecryption";
	Else
		Items.Pages.CurrentPage = Items.PagePurposeWithoutDigitalSignature;
		Purpose = "ForEncryptionAndDecryption";
	EndIf;
	
	Items.FormAdd.Visible = True;
	Items.FormNext.Visible = False;
	Items.FormBack.Visible = True;
	Items.FormAdd.DefaultButton = True;
	
	SetCommandsContentForEncryptionOnly(ThisObject);
	
EndProcedure

&AtClient
Procedure Back(Command)
	
	Items.Pages.CurrentPage = Items.PageMethodAddCertificate;
	Items.FormBack.Visible = False;
	
	SetCommandsContentOnChangingCertificateAddMethod();
	
EndProcedure

&AtClient
Procedure AddFromFile(Command)
	
	Close("ForEncryptionOnlyFromFile");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SetCommandsContentOnChangingCertificateAddMethod()
	
	AddApplication = MethodAddCertificate = "RequestForCertificateIssue";
	
	Items.FormAdd.Visible = AddApplication;
	Items.FormNext.Visible = Not AddApplication;
	Items.FormAdd.DefaultButton = AddApplication;
	Items.FormNext.DefaultButton = Not AddApplication;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetCommandsContentForEncryptionOnly(Form)
	
	Items = Form.Items;
	FromFile = Form.Purpose = "ForEncryptionOnly";
	
	Items.AddFromFile1.Visible = FromFile;
	Items.AddFromFile2.Visible = FromFile;
	
EndProcedure

#EndRegion
