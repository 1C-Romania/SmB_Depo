&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	FormsAtServer.CatalogFormOnCreateAtServer(ThisForm, Cancel, StandardProcessing);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	FormsAtClient.CatalogListFormOnOpen(ThisForm, Cancel);
	If Not PreserveTempUserSetting Then
		DataCompositionAtClientAtServer.ClearTempUserSettingFilter(List.SettingsComposer.UserSettings);
	EndIf;	
EndProcedure

&AtClient
Procedure OnReopen()
	If Not PreserveTempUserSetting Then
		DataCompositionAtClientAtServer.ClearTempUserSettingFilter(List.SettingsComposer.UserSettings);
	EndIf;	
EndProcedure

&AtClient
Procedure SetFilter(Val CatalogItem, Val FilterStructure) Export
	
	DataCompositionAtClientAtServer.ClearTempUserSettingFilter(List.SettingsComposer.UserSettings);
	For Each KeyAndValue In FilterStructure Do
		DataCompositionAtClientAtServer.SetUserSettingFilter(List.SettingsComposer.UserSettings,KeyAndValue.Key,KeyAndValue.Value,True,DataCompositionComparisonType.Equal);
	EndDo;		
	SetCurrentRow(CatalogItem);
	
EndProcedure

&AtClient
Procedure SetCurrentRow(Val CatalogItem)
	PreserveTempUserSetting = True;
	If CatalogItem <> Undefined Then
		Items.List.CurrentRow = CatalogItem;
	EndIf;	
EndProcedure	

