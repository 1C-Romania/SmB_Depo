#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Returns information about external data processor.
Function ExternalDataProcessorInfo() Export
	
	RegistrationParameters = AdditionalReportsAndDataProcessors.ExternalDataProcessorInfo("2.1.3.1");
	
	RegistrationParameters.Type = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalInformationProcessor();
	RegistrationParameters.Version = "1.0";
	RegistrationParameters.SafeMode = True;
	
	NewCommand = RegistrationParameters.Commands.Add();
	NewCommand.Presentation = NStr("en = 'Products need calculation'");
	NewCommand.ID = "ProductsNeedCalculation";
	NewCommand.Use = AdditionalReportsAndDataProcessorsClientServer.TypeCommandsFormOpening();
	NewCommand.ShowAlert = False;
	
	Return RegistrationParameters;
	
EndFunction

#EndRegion

#EndIf