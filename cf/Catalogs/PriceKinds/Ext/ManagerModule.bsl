#If Server Or ThickClientOrdinaryApplication Then

////////////////////////////////////////////////////////////////////////////////
// PROGRAMM INTERFACE

// The procedure receives basic kind of the sale prices from user settings.
//
Function GetMainKindOfSalePrices() Export
	
	PriceKindSales = SmallBusinessReUse.GetValueByDefaultUser(UsersClientServer.AuthorizedUser(), "MainPriceKindSales");
	
	Return ?(ValueIsFilled(PriceKindSales), PriceKindSales, Catalogs.PriceKinds.Wholesale);
	
EndFunction// FillKindPrices()

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see the fields content in the PrintManagement.CreatePrintCommandsCollection function
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion


#EndIf