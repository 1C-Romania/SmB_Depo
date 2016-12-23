
// Procedure - command handler "SetInterval".
//
&AtClient
Procedure SetInterval(Command)
	
	Dialog = New StandardPeriodEditDialog();
	
	Dialog.Period.StartDate    = Report.StartDate;
	Dialog.Period.EndDate = Report.EndDate;
	
	Dialog.Show(New NotifyDescription("SetIntervalEnd", ThisObject, New Structure("Dialog", Dialog)));
	
EndProcedure

&AtClient
Procedure SetIntervalEnd(Result1, AdditionalParameters) Export
	
	Dialog = AdditionalParameters.Dialog;
	
	If ValueIsFilled(Result1) Then
		
		Report.StartDate    = Dialog.Period.StartDate;
		Report.EndDate = Dialog.Period.EndDate;
		
	EndIf;
	
EndProcedure // SetInterval()

// Procedure - form event handler "OnOpen".
//
&AtClient
Procedure OnOpen(Cancel)
	
	If Not ValueIsFilled(Report.StartDate) AND Not ValueIsFilled(Report.EndDate) Then
		
		Report.StartDate    = BegOfYear(CurrentDate());
		Report.EndDate = CurrentDate();
		
	EndIf;
	
EndProcedure // OnOpen()

// Procedure fills report fields by values if they are not filled.
//
&AtServer
Procedure FillValuesByDefault(Settings)
	
	If Not ValueIsFilled(Settings.Get("Report.Company")) Then
		
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If ValueIsFilled(SettingValue) Then
			Report.Company = SettingValue;
		Else
			Report.Company = Catalogs.Companies.MainCompany;		
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(Settings.Get("Report.StructuralUnit")) Then
		
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainWarehouse");
		If ValueIsFilled(SettingValue) Then
			Report.StructuralUnit = SettingValue;
		Else
			Report.StructuralUnit = Catalogs.StructuralUnits.MainWarehouse;	
		EndIf;
		
	EndIf;
	
EndProcedure // FillByValuesDefault()

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FillValuesByDefault(Settings);
	
EndProcedure // OnLoadDataFromSettingsAtServer()

&AtServer
Procedure OnSaveUserSettingsAtServer(Settings)
	ReportsVariants.OnSaveUserSettingsAtServer(ThisObject, Settings);
EndProcedure














