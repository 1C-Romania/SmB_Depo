#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Defines the endpoints (subscribers) for
// broadcast channel of "Publishing/Subscription" type.
//
// Parameters:
//  MessageChannel - String - Identifier of the broadcast messages channel.
//
// Returns:
//  Array - Items array of endpoints, contains the items of PlanExchangeRef.MessageExchange type.
//
Function MessageChannelSubscribers(Val MessageChannel) Export
	
	QueryText =
	"SELECT
	|	RecipientSubscriptions.Recipient AS Recipient
	|FROM
	|	InformationRegister.RecipientSubscriptions AS RecipientSubscriptions
	|WHERE
	|	RecipientSubscriptions.MessageChannel = &MessageChannel";
	
	Query = New Query;
	Query.SetParameter("MessageChannel", MessageChannel);
	Query.Text = QueryText;
	
	Return Query.Execute().Unload().UnloadColumn("Recipient");
EndFunction

#EndRegion

#EndIf