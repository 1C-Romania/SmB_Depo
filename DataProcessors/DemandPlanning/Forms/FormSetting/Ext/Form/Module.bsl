
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

&AtClient
// Procedure is called on clicking the "FinishEdit" button of command form panel.
//
Procedure FinishEdit(Command)
	
	StructureOfFormAttributes = New Structure;
	StructureOfFormAttributes.Insert("SettingsComposer", SettingsComposer);
	Close(StructureOfFormAttributes);
	
EndProcedure // FinishEdit()

&AtClient
// Procedure is called on clicking the "Cancel" button of command form panel.
//
Procedure Cancel(Command)
	
	Close(DialogReturnCode.Cancel);
	
EndProcedure // Cancel()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SettingsSource = New DataCompositionAvailableSettingsSource(Parameters.SchemaURLCompositionData);
	
	SettingsComposer.LoadSettings(Parameters.FilterSettingComposer.Settings);
	SettingsComposer.LoadUserSettings(Parameters.FilterSettingComposer.UserSettings);
	SettingsComposer.LoadFixedSettings(Parameters.FilterSettingComposer.FixedSettings);
	
	SettingsComposer.Initialize(SettingsSource);
	
EndProcedure // OnCreateAtServer()



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
