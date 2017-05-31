&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	FormsAtServer.CatalogFormOnCreateAtServer(ThisForm, Cancel, StandardProcessing);
	If Items.List.ChoiceMode Then
		List.AutoSaveUserSettings = False;
	EndIf;	
	
	If  Parameters.Filter.Property("PreserveTempUserSetting") Then
		PreserveTempUserSetting=Parameters.Filter.PreserveTempUserSetting;
	EndIf;
	
	If  Parameters.Filter.Property("ItemType") Then
		SetFilterByItemTypeAtServer(Parameters.Filter.ItemType);
	EndIf;
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

&AtServer
Procedure SetFilterByItemTypeAtServer(Val ItemType, Val Item = Undefined) Export
	
	DataCompositionAtClientAtServer.ClearTempUserSettingFilter(List.SettingsComposer.UserSettings);	
	DataCompositionAtClientAtServer.SetUserSettingFilter(List.SettingsComposer.UserSettings,"Ref.AccountingGroup.ItemType",ItemType,True,DataCompositionComparisonType.Equal);	

EndProcedure

			
&AtClient
Procedure SetFilterByItemType(Val ItemType, Val Item = Undefined) Export
	
	DataCompositionAtClientAtServer.ClearTempUserSettingFilter(List.SettingsComposer.UserSettings);
	DataCompositionAtClientAtServer.SetUserSettingFilter(List.SettingsComposer.UserSettings,"Ref.AccountingGroup.ItemType",ItemType,True,DataCompositionComparisonType.Equal);
	
	SetCurrentRow(Item);

EndProcedure

&AtClient
Procedure SetCurrentRow(Val Item)
	PreserveTempUserSetting = True;
	If Item <> Undefined Then
		Items.List.CurrentRow = Item;
	EndIf;	
EndProcedure	