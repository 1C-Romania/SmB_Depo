#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

Procedure WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries) Export
	
	DataExchangeServer.ExternalResourcesQueryForDataExchangeMessagesDirectory(PermissionsQueries, ThisObject);
	
EndProcedure

#EndRegion

#EndIf