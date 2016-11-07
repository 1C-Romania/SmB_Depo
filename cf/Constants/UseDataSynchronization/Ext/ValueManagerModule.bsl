#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnWrite(Cancel)
	
	If Value = True Then
		
		DataSeparationEnabled = CommonUseReUse.DataSeparationEnabled();
		Constants.UseDataSynchronizationInLocalMode.Set(NOT DataSeparationEnabled);
		Constants.UseDataSynchronizationSaaS.Set(DataSeparationEnabled);
		
	Else
		
		Constants.UseDataSynchronizationInLocalMode.Set(False);
		Constants.UseDataSynchronizationSaaS.Set(False);
		
	EndIf;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Value = True Then
		DataExchangeServer.OnDataSynchronizationEnabling(Cancel);
	Else
		DataExchangeServer.OnDataSynchronizationDisabling(Cancel);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf