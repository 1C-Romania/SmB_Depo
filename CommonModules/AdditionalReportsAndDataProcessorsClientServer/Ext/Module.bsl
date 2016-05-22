////////////////////////////////////////////////////////////////////////////////
// Subsystem "Additional reports and data processors".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

////////////////////////////////////////////////////////////////////////////////
// Names of object kinds.

// Print form.
Function DataProcessorKindPrintForm() Export
	
	Return "PrintForm"; // not localized
	
EndFunction

// Object filling.
Function DataProcessorKindObjectFilling() Export
	
	Return "ObjectFilling"; // not localized
	
EndFunction

// Creation of linked objects.
Function DataProcessorKindCreatingRelatedObjects() Export
	
	Return "CreatingLinkedObjects"; // not localized
	
EndFunction

// Assigned report.
Function DataProcessorKindReport() Export
	
	Return "Report"; // not localized
	
EndFunction

// Additional data processor.
Function DataProcessorKindAdditionalInformationProcessor() Export
	
	Return "AdditionalInformationProcessor"; // not localized
	
EndFunction

// Additional report.
Function DataProcessorKindAdditionalReport() Export
	
	Return "AdditionalReport"; // not localized
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Names of commands kinds.

// Client method call.
Function TypeCommandsClientMethodCall() Export
	
	Return "CallOfClientMethod"; // not localized
	
EndFunction

// Server method call.
Function TypeCommandsServerMethodCall() Export
	
	Return "CallOfServerMethod"; // not localized
	
EndFunction

// Opening a form.
Function TypeCommandsFormOpening() Export
	
	Return "FormOpening"; // not localized
	
EndFunction

// Filling a form.
Function TypeCommandsFillForm() Export
	
	Return "FillForm"; // not localized
	
EndFunction

// Script in safe mode.
Function TypeCommandsScriptInSafeMode() Export
	
	Return "ScriptInSafeMode"; // not localized
	
EndFunction

// Data import from file.
Function CommandTypeDataLoadFromFile() Export
	
	Return "DataLoadFromFile"; // not localized
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Names of form types. It is used when setting the assigned objects.

// List form identifier.
Function FormTypeList() Export
	
	Return "ListForm"; // not localized
	
EndFunction

// Object form identifier.
Function ObjectFormType() Export
	
	Return "ObjectForm"; // not localized
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

// Filter for chooser or save dialogs of additional reports and data processors.
Function ChooserAndSaveDialog() Export
	
	Filter = NStr("en = 'External reports and processings (*.%1, *.%2)|*.%1;*.%2|External reports (*.%1)|*.%1|External processings (*.%2)|*.%2'");
	Filter = StringFunctionsClientServer.PlaceParametersIntoString(Filter, "erf", "epf");
	Return Filter;
	
EndFunction

// Identifier that is used for desktop.
Function DesktopID() Export
	
	Return "Desktop"; // not localized
	
EndFunction

// Subsystem name.
Function SubsystemDescription(LanguageCode) Export
	
	Return NStr("en = 'Additional reports and data processors'", ?(LanguageCode = Undefined, CommonUseClientServer.MainLanguageCode(), LanguageCode));
	
EndFunction

#EndRegion
