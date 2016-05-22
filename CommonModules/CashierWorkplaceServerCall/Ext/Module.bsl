#Region CatalogProcessingProceduresAndFunctionsSettingsCWP

// The function receives FIA setup for a working place
//
// Parameters:
//  Workplace - Catalog.Workplaces - current working place (for working with connected equipment)
//
Function GetCWPSetup(Workplace) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED TOP 1
		|	SettingsCWP.Ref
		|FROM
		|	Catalog.SettingsCWP AS SettingsCWP
		|WHERE
		|	SettingsCWP.Workplace = &Workplace
		|	AND Not SettingsCWP.DeletionMark";
	
	Query.SetParameter("Workplace", Workplace);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		Return Selection.Ref;
	Else
		NewCWPSetting = Catalogs.SettingsCWP.CreateItem();
		NewCWPSetting.FillInButtonsTableFromLayout();
		NewCWPSetting.Workplace = Workplace;
		NewCWPSetting.Description = TrimAll(Workplace.Description);
		Try
			NewCWPSetting.Write();
			
			Return NewCWPSetting.Ref;
		Except
			Message = New UserMessage;
			Message.Text = ErrorDescription();
			Message.Message();
			
			Return Undefined;
		EndTry;
	EndIf;
	
EndFunction

// The procedure writes the new value of the attribute DonNotShowWhenCashdeskChoiceFormIsOpened
//
// Parameters:
//  CWPSetting - Catalog.SettingsCWP - Current CWP settings (determined by
//  working place) DonNotShowWhenCashdeskChoiceFormIsOpened - Boolean - New value of attribute
//
Procedure UpdateSettingsCWP(CWPSetting, DontShowOnOpenCashdeskChoiceForm) Export
	
	SetPrivilegedMode(True);
	
	If Not CWPSetting.IsEmpty() AND CWPSetting.DontShowOnOpenCashdeskChoiceForm <> DontShowOnOpenCashdeskChoiceForm Then
		SetupCWPObject = CWPSetting.GetObject();
		SetupCWPObject.DontShowOnOpenCashdeskChoiceForm = DontShowOnOpenCashdeskChoiceForm;
		Try
			SetupCWPObject.Write();
		Except
			Message = New UserMessage;
			Message.Text = "Failed to make changes. "+Chars.LF+ErrorDescription();
			Message.Field = "DontShowOnOpenCashdeskChoiceForm";
			Message.Message();
		EndTry;
	EndIf;
	
	SetPrivilegedMode(False);
	
EndProcedure

#EndRegion