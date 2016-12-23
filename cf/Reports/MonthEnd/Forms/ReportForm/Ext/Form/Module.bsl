
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	StandardProcessing = False;
	
	If Parameters.Property("BeginOfPeriod") Then
		
		BeginOfPeriod = Parameters["BeginOfPeriod"];
		SetParameterAtServer("BeginOfPeriod", BeginOfPeriod);
		
	EndIf;
	
	If Parameters.Property("EndOfPeriod") Then
		
		EndOfPeriod = Parameters["EndOfPeriod"];
		SetParameterAtServer("EndOfPeriod", EndOfPeriod);
		
	EndIf;
	
	If Parameters.Property("Company") Then
		
		Company = Parameters["Company"];
		SetParameterAtServer("Company", Company);
		
	Else
		
		Cancel = True;
		
	EndIf;
	
	If Parameters.Property("GeneratingDate") Then
		
		Company = Parameters["GeneratingDate"];
		SetParameterAtServer("GeneratingDate", Company);
		
	EndIf;
	
	Items.MainCommandBar.Visible = False;
	
EndProcedure

&AtServer
Procedure SetParameterAtServer(ParameterName, ParameterValue)
	
	CompositionSetup = Report.SettingsComposer.Settings;
	FoundSetting= CompositionSetup.DataParameters.Items.Find(ParameterName);
	
	If Not FoundSetting = Undefined Then
		
		UserSettingsItem = Report.SettingsComposer.UserSettings.Items.Find(
			FoundSetting.UserSettingID
		);
		UserSettingsItem.Use = True;
		UserSettingsItem.Value = ParameterValue;
		
	EndIf;
	
EndProcedure // SetParameterAtServer()

&AtClient
Procedure OnOpen(Cancel)
	
	ComposeResult();
	
EndProcedure

















