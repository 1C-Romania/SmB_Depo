#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Function should return:
// True if the correspondent supports the exchange scenario in which the current IB works in local mode, while correspondent works in service model. 
// 
// False - if such exchange scenario is not supported.
//
Function CorrespondentSaaS() Export
	
	Return False;
	
EndFunction // CorrespondentSaaS()

// Receives the array of the exchange nodes used in exchange settings.
//
Function GetUsedNodesExchangePlan() Export
	
	Query = New Query(
		"SELECT ALLOWED
		|	MobileApplication.Ref AS Ref
		|FROM
		|	ExchangePlan.MobileApplication AS MobileApplication
		|WHERE
		|	Not MobileApplication.DeletionMark
		|	AND MobileApplication.Ref <> &ThisNode");
		
	Query.SetParameter("ThisNode", ExchangePlans.MobileApplication.ThisNode());
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Returns the name of configurations family. 
// Used to support exchanges with configurations changes in service.
//
Function SourceConfigurationName() Export
	
	Return "SmallBusiness";
	
EndFunction // SourceConfigurationName()

// Allows to predefine the exchange plan settings specified by default.
// For values of the default settings, see DataExchangeServer.DefaultExchangePlanSettings
// 
// Parameters:
// Settings - Structure - Contains default settings
//
// Example:
//	Settings.WarnAboutExchangeRulesVersionsMismatch = False;
Procedure DefineSettings(Settings) Export
	
	
	
EndProcedure // DefineSettings()

#EndIf