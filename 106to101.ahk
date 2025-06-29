;logFile := A_ScriptDir "\debug_log.txt" ; スクリプトと同じディレクトリにログファイルを作成
logAdd(str) {
	;FileAppend(str ,logFile)
}
;-------------------------------------------------------------------------------
; Scrolling Mode for Track ball
; 進むボタン長押しで有効化
; 進むボタン短押しで解除
;-------------------------------------------------------------------------------
Global IsScrolling := false
Global initial_pos_x := 0
Global initial_pos_y := 0

; スクロールモード時のマウスカーソル監視
ChkMouseMove() {
	logAdd("30ms:" . "`n")
	Global IsScrolling
	;スクロールモードであれば スクロール量に応じてWheeDown/Up操作を行う
	if ( IsScrolling ) {
		MouseGetPos &pos_x,&pos_y
		BlockInput "MouseMove"
		; マウスカーソルを有効化した直後の位置に戻す
		MouseMove initial_pos_x,initial_pos_y,0
		movex := pos_x - initial_pos_x
		movey := pos_y - initial_pos_y

		logAdd("move: " . movex . " " . movey . "`n")

		if( (movex != 0) || (movey != 0) ) {
			SendWheelFunc(movex, movey)
		}

		BlockInput "MouseMoveOff"
		; カーソル監視を継続
		SetTimer ChkMouseMove, -30
	}
}

; カーソルを隠す
HideCursorFn() {
    DllCall("ShowCursor", "Int", 0) ; 0 を渡すとカウンターをデクリメント
}

; カーソルを表示する
ShowCursorFn() { ; 関数名が既存のAutoHotkeyコマンドと重複しないように注意 (ShowCursorFnなど)
    DllCall("ShowCursor", "Int", 1) ; 1 を渡すとカウンターをインクリメント
}

; Wheelのイベントを送信
SendWheelFunc(x,y) {

	accele := CalculateAccelerationFactor(x,y)

	if( (accele.times == 0) || (accele.value == 0) ) {
		return
	}

	if ( (y==0) || (abs(x / y) > 0.7) ) {
		if (x > 0) {
			logAdd("right:" . accele.times . " "  . accele.value "`n")
			SendInputWheelRight(accele.times,accele.value)
		} else {
			logAdd("left:" . accele.times . " "  . accele.value "`n")
			SendInputWheelLeft(accele.times,accele.value)
		}
	} 
	else if ( abs(y) != 0 ) {
		if (y > 0) {
			logAdd("down:" . accele.times . " "  . accele.value "`n")
			SendInputWheelDown(accele.times,accele.value)
		} else { 
			logAdd("up:" . accele.times . " "  . accele.value "`n")
			SendInputWheelUp(accele.times,accele.value)
		}
	}
}

CalculateAccelerationFactor(x,y) {
	absx := abs(x)
	absy := abs(y)
	sum := Floor(absx+absy)

	value := 1 
	if( sum > 200 ) {
		times := sum
	}
	else if( sum > 50 ) {
		times := Floor(sum / 10 )
	}
	else if( sum > 5 ){
		times := 1
	}
	else{
		times := 0
	}
	return { times: times, value: value }
}

SendInputWheelRight(times, value) {
	num := times * value
	str := "{WheelRight " . num . "}"
	SendInput(str)
}
SendInputWheelLeft(times, value) {
	num := times * value
	str := "{WheelLeft " . num . "}"
	SendInput(str)
}
SendInputWheelUp(times, value) {
	num := times * value
	str := "{WheelUp " . num . "}"
	SendInput(str)
}
SendInputWheelDown(times, value) {
	num := times * value
	str := "{WheelDown " . num . "}"
	SendInput(str)
}

disableToolTip() {
	ToolTip
}

; マウスの進むボタン
XButton2:: {
	; 進むボタンが押された瞬間（長押し判定用）
	if KeyWait("XButton2","T0.2") 
	{
		;BlockInput "MouseMoveOff"
		if ( IsScrolling == true ) {
			; スクロールモードを解除
			ToolTip "disable scroll"
			global IsScrolling := false
			; 1秒後にツールチップを非表示にする
			SetTimer disableToolTip, -1000
		}
		else {
			; スクロールモードでない場合は通常処理
			Send "{XButton2}"
		}
	} else {
		; 長押しされたらスクロールモードに切り替え
		ToolTip "enable scroll"
		global IsScrolling := true
		; 現在のカーソル位置を保存
		MouseGetPos &pos_x,&pos_y
		global initial_pos_x := pos_x
		global initial_pos_y := pos_y
		; マウスカーソルの監視を動かす
		SetTimer ChkMouseMove, -30
		;BlockInput "MouseMove"
		;HideCursorFn()
	}
}

;-------------------------------------------------------------------------------
; 106 -> 101
;-------------------------------------------------------------------------------
#UseHook
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 1段目
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SC029::`        ;         半角/全角     -> `
+SC029::~       ; Shift + 半角/全角     -> ~
!SC029::SC029   ; Alt   + 半角/全角     -> 半角/全角
+2::@           ; Shift + 2         ["] -> @
+6::^           ; Shift + 6         [&] -> ^
+7::&           ; Shift + 7         ['] -> &
+8::*           ; Shift + 8         [(] -> *
+9::(           ; Shift + 9         [)] -> (
+0::)           ; Shift + 0         [ ] -> )
+-::_           ; Shift + -         [=] -> _
^::=            ;                   [^] -> =
+^::+           ; Shift + ^         [~] -> +
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 2段目
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@::[        ;                   [@] -> [
+@::`{      ; Shift + @         [`] -> {
[::]        ;                   [[] -> ]
+[::}       ; Shift + [         [{] -> }
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 3段目
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
:::'        ;                   [:] -> '
+;:::       ; Shift + ;         [+] -> :
*::"        ; Shift + :         [*] -> "
]::\        ;                   []] -> \
+]::|       ; Shift + ]         [}] -> |

