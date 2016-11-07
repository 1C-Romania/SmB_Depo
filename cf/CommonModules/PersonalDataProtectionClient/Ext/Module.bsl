////////////////////////////////////////////////////////////////////////////////
// Subsystem "Personal data protection".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Executes go to personal data processing consent form, it is used as the print handler.
//
// Parameters:
// PrintParameters - the parameters structure of the print command processor must contain the PrintObjects and Form fields.
//
Function OpenPersonalDataProcessingConsentForm(PrintParameters) Export
	
	OpenForm("DataProcessor.PersonalDataProcessingConsent.Form", New Structure("Subjects", PrintParameters.PrintObjects), PrintParameters.Form);
	
EndFunction

#EndRegion
