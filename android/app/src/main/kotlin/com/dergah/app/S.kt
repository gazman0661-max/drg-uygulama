package com.dergah.app

import android.content.Context

/** Yerelleştirilmiş metinlere (res/values, values-tr, values-ar) bağlam gerektirmeden erişim. */
object S {
    @Volatile private var app: Context? = null

    fun init(c: Context) { app = c.applicationContext ?: c }

    private fun ctx(): Context = app ?: throw IllegalStateException("S.init çağrılmadı")

    fun str(id: Int): String = ctx().getString(id)
    fun fmt(id: Int, vararg a: Any): String = ctx().getString(id, *a)

    private val P = intArrayOf(R.string.p0, R.string.p1, R.string.p2, R.string.p3, R.string.p4, R.string.p5)
    private val D = intArrayOf(R.string.dat0, R.string.dat1, R.string.dat2, R.string.dat3, R.string.dat4, R.string.dat5)
    private val KN = intArrayOf(R.string.kn0, R.string.kn1, R.string.kn2)

    /** İmsak, Güneş, Öğle, İkindi, Akşam, Yatsı (cihaz diline göre) */
    fun labels(): Array<String> = Array(6) { str(P[it]) }
    /** Geri sayım etiketi ("Sabaha" / "Fajr in" / "الفجر بعد") */
    fun dat(): Array<String> = Array(6) { str(D[it]) }
    /** Kerahat vakti adları (doğuş, istiva, batış) */
    fun kerahatNames(): Array<String> = Array(3) { str(KN[it]) }
}
