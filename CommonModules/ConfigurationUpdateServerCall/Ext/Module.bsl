////////////////////////////////////////////////////////////////////////////////
// Subsystem "Configuration update".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Receives the settings of update assistant from common settings storage.
//
// Details - see description ConfigurationUpdate.ReceiveAssistantSettingsStructure().
//
Function GetSettingsStructureOfAssistant() Export
	
	Return ConfigurationUpdate.GetSettingsStructureOfAssistant();
	
EndFunction

// Writes the settings of update assistant to common settings storage.
//
// Details - see description ConfigurationUpdate.WriteAssistantSettingsStructure().
//
Procedure WriteStructureOfAssistantSettings(ConfigurationUpdateOptions, MessagesForEventLogMonitor = Undefined) Export
	
	ConfigurationUpdate.WriteStructureOfAssistantSettings(ConfigurationUpdateOptions, MessagesForEventLogMonitor);
	
EndProcedure

#EndRegion
