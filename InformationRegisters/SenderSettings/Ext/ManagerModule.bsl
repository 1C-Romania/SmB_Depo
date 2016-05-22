#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Defines the endpoints for which the specified message channel is assigned in the current information system.
//
// Parameters:
//  MessageChannel - String. Address messages channel identifier.
//
// Returns:
//  Type: Array. Array of endpoints items.
//  Array contains the items of PlanExchangeRef.MessageExchange type.
//
Function MessageChannelSubscribers(Val MessageChannel) Export
	
	QueryText =
	"SELECT
	|	SenderSettings.Recipient AS Recipient
	|FROM
	|	InformationRegister.SenderSettings AS SenderSettings
	|WHERE
	|	SenderSettings.MessageChannel = &MessageChannel";
	
	Query = New Query;
	Query.SetParameter("MessageChannel", MessageChannel);
	Query.Text = QueryText;
	
	Return Query.Execute().Unload().UnloadColumn("Recipient");
EndFunction

#EndRegion

#EndIf