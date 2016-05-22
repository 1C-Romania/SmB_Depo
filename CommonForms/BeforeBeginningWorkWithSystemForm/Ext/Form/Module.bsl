
// Procedure - command handler BalanceEntering.
//
&AtClient
Procedure BalanceEntering(Command)
	
	If SmallBusinessServer.InfobaseUserWithFullAccess(,, False) Then
		OpenFormBalanceEntering();
	Else
		MessageText = NStr("en='Only the user with the ""Administrator"" access rights profile is able to perform this action.'");
		ShowMessageBox(Undefined,MessageText);
	EndIf;
	
EndProcedure // BalanceEntering()

// Procedure - command handler FillInformationAboutCompany.
//
&AtClient
Procedure FillInformationAboutCompany(Command)
	
	If SmallBusinessServer.InfobaseUserWithFullAccess(,, False) Then
		OpenFormFillingInformationAboutCompany();
	Else
		MessageText = NStr("en='Only the user with the ""Administrator"" access rights profile is able to perform this action.'");
		ShowMessageBox(Undefined,MessageText);
	EndIf;
	
EndProcedure // FillInformationAboutCompany()

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not CommonUse.OnCreateAtServer(ThisForm, Cancel, StandardProcessing) Then
		
		Return;
		
	EndIf;
	
	If Constants.InitialSettingCompanyDetailsFilled.Get() Then
		Items.FillInformationAboutCompanyStatus.Picture = PictureLib.Done;
	Else
		Items.FillInformationAboutCompanyStatus.Picture = PictureLib.GoToNext;
	EndIf;
	
	If Constants.InitialSettingOpeningBalancesFilled.Get() Then
		Items.BalanceEnteringStatus.Picture = PictureLib.Done;
	Else
		Items.BalanceEnteringStatus.Picture = PictureLib.GoToNext;
	EndIf;
	
EndProcedure // OnCreateAtServer()

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	SetButtonParameters();
	
EndProcedure // OnOpen()

// Procedure sets button parameters.
//
&AtClient
Procedure SetButtonParameters()
	
	If Items.FillInformationAboutCompanyStatus.Picture = PictureLib.Done Then
		Items.FillInformationAboutCompany.Title = NStr("en='Change'");
	EndIf;
	
	If Items.BalanceEnteringStatus.Picture = PictureLib.Done Then
		Items.BalanceEntering.Title = NStr("en='Change'");
	EndIf;
	
EndProcedure // SetButtonParameters()

// Procedure opens the form for filling the data of the company.
//
&AtClient
Procedure OpenFormFillingInformationAboutCompany()
	
	Notification = New NotifyDescription("OpenFormFillingInformationAboutCompanyCompletion",ThisForm);
	OpenForm("CommonForm.FormFillingInformationAboutCompany",,,,,,Notification);
	
EndProcedure // OpenFormFillingInformationAboutCompany()

&AtClient
Procedure OpenFormFillingInformationAboutCompanyCompletion(CompletedFilling,Parameters) Export
	
	If ValueIsFilled(CompletedFilling) AND CompletedFilling Then
		Items.FillInformationAboutCompanyStatus.Picture = PictureLib.Done;
		SetButtonParameters();
	EndIf;
	
	SettingsModified = False;
	SmallBusinessServer.ConfigureUserDesktop(SettingsModified);
	If SettingsModified Then
		RefreshInterface();
	EndIf;
	
EndProcedure

// Procedure opens the form for entering the balances.
//
&AtClient
Procedure OpenFormBalanceEntering()
	
	Notification = New NotifyDescription("OpenFormInputBalancesCompletion",ThisForm);
	OpenForm("CommonForm.FormBalancesEntering",,,,,,Notification);
	
EndProcedure // OpenFormBalancesEntering()

&AtClient
Procedure OpenFormInputBalancesCompletion(CompletedFilling,Parameters) Export
	
	If ValueIsFilled(CompletedFilling) AND CompletedFilling Then
		Items.BalanceEnteringStatus.Picture = PictureLib.Done;
		SetButtonParameters();
	EndIf;
	
	SettingsModified = False;
	SmallBusinessServer.ConfigureUserDesktop(SettingsModified);
	If SettingsModified Then
		RefreshInterface();
	EndIf;
	
EndProcedure
