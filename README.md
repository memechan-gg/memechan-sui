# Memechan

- $\Omega_M$ is the amount of tokens to launch in the AMM
- $\Gamma_M$ is the amount of tokens locked in staking for LP
- $\Gamma_S$ is the target amount of Sui to raise in the bonding phase
- $PF$ is a **Price Factor** representing the difference between the terminal price in the seed phase phase vs. the initial price in the live phase

We have a piece-wise linear equation:

$$
F(S) = \begin{cases} 0 & \text{if } S < 0 \\ \hat{M} = aS+b & \text{if } 0 \leq S \leq \Gamma_S \\ 0 & \text{if } S > \Gamma_S \end{cases}
$$


From which we compute the amount $\Delta M$ to swap, given an input $\Delta S$:

$$
\Delta M = \int_{\hat{S_t}}^{S_{t+1}} f(S) \, ds = \frac{a S_{t+1}^2}{2}+bS_{t+1}+C-(\frac{aS_t^2}{2}+bS_t + C) = \frac{a S_{t+1}^2}{2}+bS_{t+1}-\frac{aS_t^2}{2}-bS_t = \frac{a (S_{t+1}^2 -S_t^2)}{2}+b(S_{t+1}-S_t)
$$

**Restriction 1:** The area under the curve must be equal to the target amount of tokens to sell in the seed phase:

$$
\int_{0}^{\Gamma_S} f(x) \, dx = \Gamma_M
$$

The primitive from $0$ to $\Gamma_S$ is:

$$
(\frac{a​\Gamma_S^2}{2}+b\Gamma_S+C)−(\frac{a×0^2}{2}+b×0+C) \Leftrightarrow \\ \frac{a​\Gamma_S^2}{2}+b\Gamma_S+C−C \Leftrightarrow \\ \frac{a​\Gamma_S^2}{2}+b\Gamma_S
$$

**Therefore the restriction follows:**

$$
\Gamma_M = \frac{a​\Gamma_S^2}{2}+b\Gamma_S
$$

**Restriction 2:** The terminal seed price, needs to be the initial price of the AMM pool times a certain price factor.

We know that the initial price in the AMM pool is given by:

$$
Initial Price=\frac{\Gamma_S}{\Omega_M}
$$

Therefore we conclude that when:

$$
S=\Gamma_S \Longrightarrow \frac{1}{\hat{M}}= \frac{\Gamma_S}{\Omega_M.PF}
$$

Therefore it follows:

$$
\hat{M}= \frac{\Omega_M}{\Gamma_S}.PF
$$

...



We are left to find out the values of $a$ and $b$ for $\hat{M} = aS+b$ that satisfy the above restrictions:

$$
\begin{align*} \begin{cases} \hat{M} = aS+b \\ S = \Gamma_S \\ \hat{M} = \frac{\Omega_M . PF}{\Gamma_S} \end{cases} \Longrightarrow \begin{cases} \frac{\Omega_M . PF}{\Gamma_S} = a\Gamma_S+b \\ ... \\ ... \end{cases} \\ \begin{cases} b = \frac{\Omega_M . PF}{\Gamma_S} - a\Gamma_S \\ ... \\ ... \end{cases} \end{align*}
$$

Now, we know that per the first restriction that $\Gamma_M = \frac{a​\Gamma_S^2}{2}+b\Gamma_S$:

$$
\begin{align*} \begin{cases} b = \frac{\Omega_M . PF}{\Gamma_S} - a\Gamma_S \\ \Gamma_M = \frac{a​\Gamma_S^2}{2}+b\Gamma_S \end{cases} \Longrightarrow \begin{cases} ... \\ \Gamma_M = \frac{a​\Gamma_S^2}{2}+\Gamma_S(\frac{\Omega_M . PF}{\Gamma_S} - a\Gamma_S) \end{cases} \\ \begin{cases} ... \\ \Gamma_M = \frac{a​\Gamma_S^2}{2}+\Omega_M PF - a\Gamma_S^2 \end{cases} \Longrightarrow \begin{cases} ... \\ \Gamma_M = -\frac{a​\Gamma_S^2}{2}+ \Omega_M PF \end{cases} \\ \begin{cases} b = \frac{\Omega_M . PF}{\Gamma_S} - a\Gamma_S \\ a = \frac{2(\Omega_M PF - \Gamma_M)}{\Gamma_S^2}\end{cases} \Longrightarrow \begin{cases} b = \frac{\Omega_M.PF}{\Gamma_S} - \frac{2(\Omega_M PF - \Gamma_M)}{\Gamma_S^2}.\Gamma_S \\ ... \end{cases} \\ \begin{cases} b = \frac{\Omega_M PF - 2\Omega_M PF+2\Gamma_M}{\Gamma_S} \\ ... \end{cases} \Longrightarrow \begin{cases} b = \frac{2\Gamma_M - \Omega_M PF}{\Gamma_S} \\ a = \frac{2(\Omega_M PF - \Gamma_M)}{\Gamma_S^2} \end{cases} \end{align*}
$$

----


**Restriction 3:** Price Factor upper bound

An intuitive way to think about the price factor is that we are scaling the point in which the bonding curve hits $x=\Gamma_S$ (in the example above it is at x = 30,000). In the scenario below the price factor is 1 and the bonding curve meets an horizontal line which represents the starting price (inverted) of the Meme coin in the live phase.

![Curve 1](assets/curve-1.png)


When we increase the price factor the "tip" of the bonding curve is elevated. Below the green horizontal line represents the boosted (inverted) price, whereas the orange line represents the initial price in the live phase.

![Curve 2](assets/curve-2.png)

The area under the curve, always needs to be equal to $\Gamma_M$, this means that in order for the tip of the curve to be elevated, the intercept has to decrease and the slope to become less negative.

There's a natural upper bound limit on the Price Factor, given that the area under the curve always needs to equal $\Gamma_M$. We can formalise this by saying that the area under the horizontal price line (green) cannot be bigger than the total meme tokens sold:

$$
PF.\frac{\Omega_M}{\Gamma_S}.\Gamma_S < \Gamma_M
$$

Where $PF.\frac{\Omega_M}{\Gamma_S}$ is the height of the price line, and $\Gamma_S$ is the length. Therefore it follows:


$$
PF.\Omega_M < \Gamma_M
$$