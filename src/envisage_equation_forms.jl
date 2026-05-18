# === Strict ENVISAGE v10.01 equation forms ===
# Source: ENVISAGE10.01_Documentation.pdf, Chapter 3.
# These strings are used by the block files to document the exact numbered
# equation implemented or approximated in the JuMP/PATH formulation.
#
# Important naming convention:
#   - The documentation prints E-1:E-2 for goods-market equilibrium and later
#     reuses E labels for emissions.  This package stores goods-market equations as E-* and emissions as EM-*
#     internally, while each formula preserves the printed label.
# ======================

const ENVISAGE_FORMULAS = OrderedDict{String,String}(
    # Commodity supply, ENVISAGE §3.3
    "S-1"  => "X[r,a,i] = gamma_s[r,a,i]*(lambda_s[r,a,i])^(-1-omega_s[r,a])*(P[r,a,i]/PX[r,a])^omega_s[r,a]*XP[r,a], or P[r,a,i]=lambda_s[r,a,i]*PX[r,a] under perfect transformation",
    "S-2"  => "PX[r,a]*XP[r,a] = sum(i, P[r,a,i]*X[r,a,i])",
    "S-3"  => "PP[r,a,i] = (1 + tau_p[r,a,i])*P[r,a,i]",
    "S-4"  => "X[r,a,i] = alpha_s[r,a,i]*(PS[r,i]/PP[r,a,i])^sigma_s[r,i]*XS[r,i], or PP[r,a,i]=PS[r,i] under perfect substitution",
    "S-5"  => "PS[r,i]*XS[r,i] = sum(a, PP[r,a,i]*X[r,a,i])",
    "S-6"  => "X[r,etd,ely] = alpha_s[r,etd,ely]*(PS[r,ely]/PP[r,etd,ely])^sigma_el[r,ely]*XS[r,ely]",
    "S-7"  => "XPOW[r,ely] = alpha_pow[r,ely]*(PS[r,ely]/PPOW[r,ely])^sigma_el[r,ely]*XS[r,ely]",
    "S-8"  => "PS[r,ely] = (alpha_s[r,etd,ely]*PP[r,etd,ely]^(1-sigma_el) + alpha_pow[r,ely]*PPOW[r,ely]^(1-sigma_el))^(1/(1-sigma_el))",
    "S-9"  => "XPB[r,pb,ely] = alpha_pb[r,pb,ely]*(lambda_pow[r,pb,ely])^(-sigma_pow[r,ely])*(PPOWN[r,ely]/PPB[r,pb,ely])^sigma_pow[r,ely]*XPOW[r,ely]",
    "S-10" => "PPOWN[r,ely] = (sum(pb, alpha_pb[r,pb,ely]*(lambda_pow[r,pb,ely]*PPB[r,pb,ely])^(-sigma_pow[r,ely])))^(-1/sigma_pow[r,ely])",
    "S-11" => "PPOW[r,ely]*XPOW[r,ely] = sum(pb, PPB[r,pb,ely]*XPB[r,pb,ely])",
    "S-12" => "X[r,elya,ely] = alpha_e[r,elya,ely]*(PPB[r,pb,ely]/PP[r,elya,ely])^sigma_pb[r,pb,ely]*XPB[r,pb,ely] if elya in pb",
    "S-13" => "PPB[r,pb,ely] = (sum(elya in pb, alpha_e[r,elya,ely]*PP[r,elya,ely]^(1-sigma_pb[r,pb,ely])))^(1/(1-sigma_pb[r,pb,ely]))",
    "S-14" => "PPB[r,pb,ely]*XPB[r,pb,ely] = sum(elya in pb, PP[r,elya,ely]*X[r,elya,ely])",

    # Income block, ENVISAGE §3.4
    "Y-1"  => "DeprY[r] = delta_f[r]*PFD[r,inv]*K_s[r]",
    "Y-2"  => "ntmY[r] = sum(s,i, tau_ntm[s,i,r]*lambda_w[s,i,r]*PWM[s,i,r]*XW[s,i,r]) or MRIO agent version",
    "Y-3"  => "YQTF[r] = chi_f[r]*sum(a, (1-kappa_f[r,cap,a])*PF[r,cap,a]*XF[r,cap,a])",
    "Y-4"  => "TrustY = sum(r, YQTF[r])",
    "Y-5"  => "YQHT[r] = chi_h[r]*TrustY",
    "Y-6"  => "Remit[s,l,r] = chi_r[s,l,r]*sum(a, (1-kappa_f[r,l,a])*PF[r,l,a]*XF[r,l,a])",
    "Y-7"  => "ODAOut[r] = chi_OO[r]*GDPMP[r]*(RGDPpc[r]/RGDPpc0[r])^eta_ODA",
    "Y-8"  => "ODAGbl = sum(r, ODAOut[r])",
    "Y-9"  => "ODAIn[r] = chi_OI[r]*ODAGbl",
    "Y-10" => "YH[r] = sum(f,a,(1-kappa_f[r,f,a])*PF[r,f,a]*XF[r,f,a]) + YQHT[r] - YQTF[r] + net_remittances - DeprY[r] + NTM transfers",
    "Y-11" => "YD[r] = (1-kappa_h[r])*YH[r]",
    "Y-12" => "YGOV[r,ptx] = sum(a,i,tau_p[r,a,i]*P[r,a,i]*X[r,a,i]) + sum(a,v,tau_uc[r,a,v]*UC[r,a,v]*XPv[r,a,v])",
    "Y-13" => "YGOV[r,vtx] = sum(a,f,tau_v[r,f,a]*PF[r,f,a]*XF[r,f,a])",
    "Y-14" => "YGOV[r,itx] = indirect sales-tax revenue over Armington agents, with ArmFlag-specific domestic/import sourcing",
    "Y-15" => "YGOV[r,mtx] = sum(s,i,tau_m[s,i,r]*lambda_w[s,i,r]*PWM[s,i,r]*XW[s,i,r]) or MRIO agent version",
    "Y-16" => "YGOV[r,etx] = sum(d,i,tau_e[r,i,d]*PE[r,i,d]*XW[r,i,d])",
    "Y-17" => "YGOV[r,wtx] = sum(h,i,tau_w[r,i,h]*PA[r,i,h]*XAw[r,i,h])",
    "Y-18" => "YGOV[r,ctx] = carbon-tax revenue over emissions, commodities and Armington agents",
    "Y-19" => "YGOV[r,dtx] = sum(f,a,kappa_f[r,f,a]*PF[r,f,a]*XF[r,f,a]) + kappa_h[r]*YH[r]",
    "Y-20" => "YFD[r,inv] = S_h[r] + S_g[r] + PW_sav*S_f[r] + DeprY[r]",

    # Final demand, ENVISAGE §3.5
    "D-1"  => "Ystar[r,h] = YD[r] - S[r,h] - sum(k, PC[r,k,h]*Pop[r]*gamma[r,k,h])",
    "D-2"  => "XC[r,k,h] = Pop[r]*gamma[r,k,h] + mu_c[r,k,h]*Ystar[r,h]/PC[r,k,h]",
    "D-3"  => "LES/ELES utility index for XC and subsistence minima",
    "D-4"  => "AIDADS marginal budget share mu_c[r,k,h] as alpha/beta-weighted function of utility",
    "D-5"  => "ZC[r,k,h] = alpha[r,k,h]*b_h[r,k,h]*u[r,h]^(b_h[r,k,h])",
    "D-6"  => "sh[r,k,h] = ZC[r,k,h] / sum(j, ZC[r,j,h])",
    "D-7"  => "CDE implicit utility normalization equals one",
    "D-8"  => "sh[r,k,h] = PC[r,k,h]*XC[r,k,h] / sum(j, PC[r,j,h]*XC[r,j,h])",
    "D-9"  => "XCnnrg[r,k,h] = alpha_cnnrg[r,k,h]*(PC[r,k,h]/PCnnrg[r,k,h])^nu_c[r,k,h]*XC[r,k,h]",
    "D-10" => "XCnrg[r,k,h] = alpha_cnrg[r,k,h]*(PC[r,k,h]/PCnrg[r,k,h])^nu_c[r,k,h]*XC[r,k,h]",
    "D-11" => "PC[r,k,h] = (alpha_cnnrg*PCnnrg^(1-nu_c)+alpha_cnrg*PCnrg^(1-nu_c))^(1/(1-nu_c))",
    "D-12" => "XA[r,in,h] = sum(k, alpha_c[r,in,k,h]*(PCnnrg[r,k,h]/PAh[r,in,h])^nu_nnrg[r,k,h]*XCnnrg[r,k,h])",
    "D-13" => "PCnnrg[r,k,h] = (sum(in,alpha_c[r,in,k,h]*PAh[r,in,h]^(1-nu_nnrg)))^(1/(1-nu_nnrg))",
    "D-14" => "XC_ely[r,k,h] = alpha_cely[r,k,h]*(PCnrg[r,k,h]/PC_ely[r,k,h])^nu_e[r,k,h]*XCnrg[r,k,h]",
    "D-15" => "XC_nely[r,k,h] = alpha_cnely[r,k,h]*(PCnrg[r,k,h]/PC_nely[r,k,h])^nu_e[r,k,h]*XCnrg[r,k,h]",
    "D-16" => "PCnrg[r,k,h] = CES dual price over electric and non-electric bundles",
    "D-17" => "XC_coa[r,k,h] = alpha_ccoa[r,k,h]*(PC_nely[r,k,h]/PC_coa[r,k,h])^nu_nely*XC_nely[r,k,h]",
    "D-18" => "XC_olg[r,k,h] = alpha_colg[r,k,h]*(PC_nely[r,k,h]/PC_olg[r,k,h])^nu_nely*XC_nely[r,k,h]",
    "D-19" => "PC_nely[r,k,h] = CES dual price over coal and oil-gas bundles",
    "D-20" => "XC_oil[r,k,h] = alpha_coil[r,k,h]*(PC_olg[r,k,h]/PC_oil[r,k,h])^nu_olg*XC_olg[r,k,h]",
    "D-21" => "XC_gas[r,k,h] = alpha_cgas[r,k,h]*(PC_olg[r,k,h]/PC_gas[r,k,h])^nu_olg*XC_olg[r,k,h]",
    "D-22" => "PC_olg[r,k,h] = CES dual price over oil and gas bundles",
    "D-23" => "XA[r,e,h] = sum(k,alpha_c[r,e,k,h]*(PC_NRG[r,k,h]/PAh[r,e,h])^nu_NRG*XC_NRG[r,k,h]) for e in NRG",
    "D-24" => "PC_NRG[r,k,h] = CES dual price over Armington energy commodities in the energy bundle",
    "D-25" => "S[r,h] = chi_s[r]*aps[r]*YD[r] for non-ELES systems",
    "D-26" => "S[r,h] = YD[r] - sum(k, PC[r,k,h]*XC[r,k,h]) for ELES",
    "D-27" => "XA[r,i,h] = ACES demand for produced good i from consumer transition matrix",
    "D-28" => "XAw[r,i,h] = waste generated by household demand",
    "D-29" => "PAh[r,i,h] = household purchaser price including waste treatment/tax wedges",
    "D-30" => "PAc[r,i,h] = PA[r,i,h] without waste wedge",
    "D-31" => "PAh[r,i,h] = PA[r,i,h]*(1+tau_w[r,i,h]) where applicable",
    "D-32" => "YFD[r,h] = sum(i, PAh[r,i,h]*XA[r,i,h])",
    "D-33" => "XA[r,i,fdc] = alpha[r,i,fdc]*(PFD[r,fdc]/PA[r,i,fdc])^sigma_fd*XFD[r,fdc]",
    "D-34" => "PFD[r,fdc] = CES dual price for other final demand bundle",
    "D-35" => "PFD[r,h,t] = Fisher consumer price index update",
    "D-36" => "YFD[r,h] = PFD[r,h]*XFD[r,h]",
    "D-37" => "YFD[r,fd] = PFD[r,fd]*XFD[r,fd]",

    # Trade summary, ENVISAGE §3.6
    "T-1"  => "XAT[r,i] = sum(aa, gamma[r,i,aa]*XA[r,i,aa])",
    "T-2"  => "XDTd[r,i] = alpha_d[r,i]*(PAT[r,i]/PDT[r,i])^sigma_mt[r,i]*XAT[r,i]",
    "T-3"  => "XMT[r,i] = alpha_m[r,i]*(PAT[r,i]/PMT[r,i])^sigma_mt[r,i]*XAT[r,i]",
    "T-4"  => "PAT[r,i] = CES dual price over domestic and aggregate import bundles",
    "T-5"  => "PA[r,i,aa] = PAT/PDT/PMT with sales taxes, gamma wedges and carbon-tax wedges",
    "T-6"  => "XD[r,i,aa] = alpha_d[r,i,aa]*(PA[r,i,aa]/PDT[r,i])^sigma_mta[r,i,aa]*XA[r,i,aa]",
    "T-7"  => "XM[r,i,aa] = alpha_m[r,i,aa]*(PA[r,i,aa]/PM[r,i,aa])^sigma_mta[r,i,aa]*XA[r,i,aa]",
    "T-8"  => "PA[r,i,aa] = agent-level Armington dual price",
    "T-9"  => "PDT_a[r,i,aa] = PDT[r,i]*(1+sales/carbon wedges)",
    "T-10" => "PM_a[r,i,aa] = PM[r,i,aa]*(1+sales/carbon wedges)",
    "T-11:T-32" => "Bilateral import allocation, export CET allocation, FOB/CIF prices, tariffs/NTMs and trade/transport margin equations as in ENVISAGE §3.6.",

    # Goods equilibrium and emissions
    "E-1" => "XDTd[r,i] = XDTs[r,i] domestic good market equilibrium (§3.7 E-1)",
    "E-2" => "XWd[r,i,d] = lambda_w[r,i,d]*XWs[r,i,d] bilateral trade equilibrium (§3.7 E-2)",
    "EM-1" => "Emissions from commodity consumption by Armington agent",
    "EM-2" => "Emissions from factor use by activity",
    "EM-3" => "Process/base emissions",
    "EM-4" => "Total regional emissions by gas",
    "EM-5" => "CO2-equivalent emissions using GWP weights",
    "EM-6" => "Emission tax/price regime equation",
    "EM-7" => "Regional/coalition emissions cap and permit allocation equation",
    "EM-8" => "Permit market clearing/revenue equation"
)

equation_formula(label::AbstractString) = get(ENVISAGE_FORMULAS, String(label), "Formula not listed; see ENVISAGE documentation and block source.")
