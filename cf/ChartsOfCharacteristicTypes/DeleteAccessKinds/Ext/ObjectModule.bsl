#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// BeforeWrite event handler prevents update
// of access kinds, which should be changed only in configuration mode.
//
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Raise
		NStr("en='You can
		|change access kinds only via configurator.
		|
		|Deleting is admissible.';ru='Изменение
		|видов доступа выполняется только через конфигуратор.
		|
		|Удаление допустимо.'");
	
EndProcedure

#EndRegion

#EndIf